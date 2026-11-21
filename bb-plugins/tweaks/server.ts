import type { BbPluginApi } from "@get-bb/plugin-sdk";
import { z } from "zod";

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
    deleteFinishedOnceAutomations: {
      type: "boolean",
      label: "Delete one-shot automations after a successful run",
      default: true,
    },
  });

  async function regenerateTitleOnInterval(threadId: string): Promise<void> {
    const { titleRegenerateEvery } = await settings.get();
    if (!Number.isInteger(titleRegenerateEvery) || titleRegenerateEvery < 1) {
      return;
    }
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
        ? outline.items.length % titleRegenerateEvery !== 0
        : interval < previous
    ) {
      return;
    }
    await bb.sdk.threads.experimental_regenerateTitle({ threadId });
    bb.log.info(`regenerated title ${JSON.stringify({
      threadId,
      userMessages: outline.items.length,
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
    await regenerateTitleOnInterval(thread.id);
    await deleteFinishedOnceAutomations(thread.projectId);
  });

  bb.events.on("thread.deleted", async ({ thread }) => {
    await bb.storage.kv.delete(`${TITLE_INTERVAL_KEY_PREFIX}${thread.id}`);
  });
}
