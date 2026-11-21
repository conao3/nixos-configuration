import type { BbPluginApi } from "@get-bb/plugin-sdk";
import { z } from "zod";
import { clientHostName } from "./client-host";
import { buildTitlePrompt, cleanTitle, runTitleCommand } from "./title";

const TITLE_INTERVAL_KEY_PREFIX = "title-interval:";

const automationListSchema = z.array(
  z.looseObject({
    id: z.string().optional(),
    projectId: z.string().optional(),
    enabled: z.boolean().optional(),
    trigger: z.looseObject({ triggerType: z.string() }).optional(),
    runCount: z.number().optional(),
    lastRunStatus: z.string().nullable().optional(),
  }),
);

export default async function plugin(bb: BbPluginApi) {
  const settings = bb.settings.define({
    titleRegenerateEvery: {
      type: "number",
      label: "Regenerate a thread's title every N user messages (0 turns it off)",
      default: 10,
    },
    titleInstructions: {
      type: "string",
      label:
        "Instructions for thread titles (used with the title command; empty keeps bb's own titles)",
      default: "",
    },
    titleCommand: {
      type: "string",
      label:
        "Shell command that reads a title prompt on stdin and prints the title",
      default: "",
    },
    deleteFinishedOnceAutomations: {
      type: "boolean",
      label: "Delete one-shot automations after a successful run",
      default: true,
    },
    tailscaleCommand: {
      type: "string",
      label:
        "tailscale command that resolves which tailnet host a browser opens bb from",
      default: "tailscale",
    },
  });

  bb.http.route("GET", "client-host", async (c) => {
    const { tailscaleCommand } = await settings.get();
    const hostName = await clientHostName(
      c.req.header("x-forwarded-for"),
      tailscaleCommand,
    );
    return c.json({ hostName });
  });

  async function writeTitle(
    threadId: string,
    currentTitle: string | null,
    instructions: string,
    command: string,
  ): Promise<void> {
    const outline = await bb.sdk.threads.conversationOutline({ threadId });
    const output = await runTitleCommand(
      command,
      buildTitlePrompt(instructions, currentTitle, outline.items),
    );
    const title = cleanTitle(output);
    if (title === null) throw new Error("title command printed no title");
    await bb.sdk.threads.update({ threadId, title });
  }

  async function regenerateTitleOnInterval(
    threadId: string,
    currentTitle: string | null,
  ): Promise<void> {
    const { titleRegenerateEvery, titleInstructions, titleCommand } =
      await settings.get();
    if (!Number.isInteger(titleRegenerateEvery) || titleRegenerateEvery < 1) {
      return;
    }
    const custom =
      titleInstructions.trim() !== "" && titleCommand.trim() !== "";
    const outline = await bb.sdk.threads.conversationOutline({
      threadId,
      role: "user",
    });
    const interval = Math.floor(outline.items.length / titleRegenerateEvery);
    const key = `${TITLE_INTERVAL_KEY_PREFIX}${threadId}`;
    const previous = await bb.storage.kv.get<number>(key);
    if (interval === previous) return;
    await bb.storage.kv.set(key, interval);
    if (
      previous === undefined
        ? !custom && outline.items.length % titleRegenerateEvery !== 0
        : interval < previous
    ) {
      return;
    }
    if (custom) {
      await writeTitle(threadId, currentTitle, titleInstructions, titleCommand);
    } else {
      await bb.sdk.threads.experimental_regenerateTitle({ threadId });
    }
    bb.log.info(`regenerated title ${JSON.stringify({
      threadId,
      userMessages: outline.items.length,
      custom,
    })}`);
  }

  async function deleteFinishedOnceAutomations(
    projectId: string,
  ): Promise<void> {
    const { deleteFinishedOnceAutomations: enabled } = await settings.get();
    if (!enabled) return;
    const automations = await bb.sdk.plugins.callRpc({
      pluginId: "automations",
      method: "automations_list",
      input: { projectId },
      outputSchema: automationListSchema,
    });
    for (const automation of automations) {
      if (
        automation.id === undefined ||
        automation.trigger?.triggerType !== "once" ||
        automation.enabled !== false ||
        (automation.runCount ?? 0) < 1 ||
        automation.lastRunStatus !== "succeeded"
      ) {
        continue;
      }
      await bb.sdk.plugins.callRpc({
        pluginId: "automations",
        method: "automations_delete",
        input: { projectId, automationId: automation.id },
        outputSchema: z.unknown(),
      });
      bb.log.info(`deleted finished one-shot automation ${JSON.stringify({
        projectId,
        automationId: automation.id,
      })}`);
    }
  }

  bb.events.on("thread.idle", async ({ thread }) => {
    await regenerateTitleOnInterval(thread.id, thread.title);
    await deleteFinishedOnceAutomations(thread.projectId);
  });

  bb.events.on("thread.deleted", async ({ thread }) => {
    await bb.storage.kv.delete(`${TITLE_INTERVAL_KEY_PREFIX}${thread.id}`);
  });
}
