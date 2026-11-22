import { useEffect, useRef, useState, useSyncExternalStore } from "react";
import {
  definePluginApp,
  useBbContext,
  experimental_useSidebarThreads,
  useBbNavigate,
  useComposer,
  useSidebarThreadDraftIds,
} from "@get-bb/plugin-sdk/app";
import type {
  BbNavigate,
  ExperimentalMessageMetadataProps,
  ExperimentalThreadRowMetadataProps,
  PluginFileOpenerProps,
  PluginSidebarThread,
} from "@get-bb/plugin-sdk/app";
import { applyTableSort, nextSortState, type SortState } from "./table-sort";

const HOST_NAME_PREFIX = /^conao-nixos-/u;

function hostLabel(name: string): string {
  return name.replace(HOST_NAME_PREFIX, "");
}

interface AppState {
  navigate: BbNavigate | null;
  threads: readonly PluginSidebarThread[];
  primaryHostId: string | null;
  draftIds: ReadonlySet<string>;
}

const appState: AppState = {
  navigate: null,
  threads: [],
  primaryHostId: null,
  draftIds: new Set(),
};

interface SelfHostState {
  hostId: string | null;
  threadVisits: number;
}

let selfHostState: SelfHostState = { hostId: null, threadVisits: 0 };
const selfHostListeners = new Set<() => void>();

function updateSelfHostState(next: Partial<SelfHostState>): void {
  selfHostState = { ...selfHostState, ...next };
  for (const listener of selfHostListeners) listener();
}

function subscribeSelfHostState(listener: () => void): () => void {
  selfHostListeners.add(listener);
  return () => {
    selfHostListeners.delete(listener);
  };
}

function useSelfHostState(): SelfHostState {
  return useSyncExternalStore(subscribeSelfHostState, () => selfHostState);
}

async function fetchClientHostName(): Promise<string | null> {
  const response = await fetch("/api/v1/plugins/tweaks/http/client-host");
  if (!response.ok) throw new Error(`client-host: ${response.status}`);
  const body: { hostName: string | null } = await response.json();
  return body.hostName;
}

function SelfHostDefault() {
  const composer = useComposer();
  const { hostId, threadVisits } = useSelfHostState();
  const pending = useRef(true);
  const seenVisits = useRef(threadVisits);
  if (seenVisits.current !== threadVisits) {
    seenVisits.current = threadVisits;
    pending.current = true;
  }
  useEffect(
    () =>
      composer.onSubmitted(() => {
        pending.current = true;
      }),
    [composer],
  );
  const environment = composer.selection?.environment;
  useEffect(() => {
    if (!pending.current || hostId === null || environment === undefined) {
      return;
    }
    pending.current = false;
    if (
      environment.type !== "provider" ||
      environment.machine?.type === "new" ||
      environment.machine?.hostId === hostId
    ) {
      return;
    }
    void composer.setSelection({
      environment: {
        ...environment,
        machine: { type: "existing", hostId },
      },
    });
  });
  return null;
}

function AppStateBridge() {
  const navigate = useBbNavigate();
  const sidebar = experimental_useSidebarThreads();
  const draftIds = useSidebarThreadDraftIds();
  const hosts = sidebar.experimental_hosts;
  const { threadId } = useBbContext();
  useEffect(() => {
    appState.navigate = navigate;
    appState.threads = sidebar.threads;
    appState.primaryHostId = hosts?.[0]?.id ?? null;
    appState.draftIds = draftIds;
  });
  const [clientHostName, setClientHostName] = useState<string | null>();
  useEffect(() => {
    let active = true;
    void fetchClientHostName().then((name) => {
      if (active) setClientHostName(name);
    });
    return () => {
      active = false;
    };
  }, []);
  useEffect(() => {
    if (hosts === undefined || clientHostName === undefined) return;
    const hostId =
      hosts.find((host) => host.name === clientHostName)?.id ?? null;
    if (hostId !== selfHostState.hostId) updateSelfHostState({ hostId });
  }, [hosts, clientHostName]);
  useEffect(() => {
    if (threadId !== null) {
      updateSelfHostState({ threadVisits: selfHostState.threadVisits + 1 });
    }
  }, [threadId]);
  return null;
}

const ARCHIVE_FOLLOW_WINDOW_MS = 5000;

function isOpenThread(thread: PluginSidebarThread | undefined): boolean {
  return thread !== undefined && !thread.isArchived && !thread.isHidden;
}

function ArchiveFollower() {
  const navigate = useBbNavigate();
  const { threads } = experimental_useSidebarThreads();
  const { threadId } = useBbContext();
  const lastView = useRef<{ threadId: string; order: string[] } | null>(null);
  const left = useRef<{
    threadId: string;
    order: string[];
    at: number;
  } | null>(null);
  useEffect(() => {
    if (threadId === null) return;
    let frame = 0;
    const snapshot = () => {
      cancelAnimationFrame(frame);
      frame = requestAnimationFrame(() => {
        const order = sidebarOrder();
        if (order.includes(threadId)) lastView.current = { threadId, order };
      });
    };
    snapshot();
    const observer = new MutationObserver(snapshot);
    observer.observe(document.body, { childList: true, subtree: true });
    return () => {
      observer.disconnect();
      cancelAnimationFrame(frame);
    };
  }, [threadId]);
  useEffect(() => {
    if (threadId !== null) {
      left.current = null;
      if (lastView.current?.threadId !== threadId) lastView.current = null;
      return;
    }
    if (lastView.current !== null) {
      left.current = { ...lastView.current, at: Date.now() };
      lastView.current = null;
    }
    const from = left.current;
    if (from === null) return;
    if (Date.now() - from.at > ARCHIVE_FOLLOW_WINDOW_MS) {
      left.current = null;
      return;
    }
    const byId = new Map(threads.map((thread) => [thread.id, thread]));
    if (isOpenThread(byId.get(from.threadId))) return;
    left.current = null;
    const index = from.order.indexOf(from.threadId);
    const next = [
      ...from.order.slice(index + 1),
      ...from.order.slice(0, Math.max(index, 0)).toReversed(),
    ].find((id) => isOpenThread(byId.get(id)));
    if (next !== undefined) navigate.toThread(next);
  }, [threadId, threads, navigate]);
  return null;
}

function useOwnHostId(): string | null {
  const { hostId } = useSelfHostState();
  const primaryHostId =
    experimental_useSidebarThreads().experimental_hosts?.[0]?.id ?? null;
  return hostId ?? primaryHostId;
}

function HostChip({
  thread,
  data: ownHostId,
}: ExperimentalThreadRowMetadataProps<string | null>) {
  if (thread.host === null || thread.host.id === ownHostId) return null;
  return (
    <span
      title={thread.host.name}
      className="rounded bg-amber-500/15 px-1 text-[0.6875rem] leading-4 text-amber-700 dark:text-amber-300"
    >
      {hostLabel(thread.host.name)}
    </span>
  );
}

function needsAttention(thread: PluginSidebarThread): boolean {
  return (
    !thread.isHidden &&
    !thread.isArchived &&
    (thread.isUnread ||
      thread.hasPendingInteraction ||
      appState.draftIds.has(thread.id))
  );
}

function sidebarOrder(): string[] {
  const rendered = Array.from(
    document.querySelectorAll<HTMLElement>("a[data-sidebar-thread-id]"),
    (anchor) => anchor.dataset.sidebarThreadId ?? "",
  ).filter((id) => id !== "");
  const seen = new Set(rendered);
  const rest = appState.threads
    .filter((thread) => !seen.has(thread.id))
    .toSorted((a, b) => b.updatedAt - a.updatedAt)
    .map((thread) => thread.id);
  return [...new Set(rendered), ...rest];
}

function goToAttentionThread(currentId: string | null, step: 1 | -1): void {
  const byId = new Map(appState.threads.map((thread) => [thread.id, thread]));
  const order = sidebarOrder().filter((id) => byId.has(id));
  if (order.length === 0) return;
  const start = currentId === null ? -1 : order.indexOf(currentId);
  for (let offset = 1; offset <= order.length; offset += 1) {
    const index =
      (((start === -1 && step === -1 ? 0 : start) + step * offset) %
        order.length +
        order.length) %
      order.length;
    const id = order[index];
    const thread = id === undefined ? undefined : byId.get(id);
    if (thread !== undefined && id !== currentId && needsAttention(thread)) {
      appState.navigate?.toThread(thread.id);
      return;
    }
  }
}

function scrollParent(element: HTMLElement): HTMLElement | null {
  for (
    let parent = element.parentElement;
    parent !== null;
    parent = parent.parentElement
  ) {
    const overflowY = getComputedStyle(parent).overflowY;
    if (
      (overflowY === "auto" || overflowY === "scroll") &&
      parent.scrollHeight > parent.clientHeight
    ) {
      return parent;
    }
  }
  return null;
}

const JUMP_MARGIN_PX = 12;

function UserMessageMarker({ message }: ExperimentalMessageMetadataProps) {
  if (message.role !== "user" || message.initiator !== "user") return null;
  return <span hidden data-tweaks-user-message={message.threadId} />;
}

function jumpToUserMessage(threadId: string, step: 1 | -1): void {
  const rows = Array.from(
    document.querySelectorAll<HTMLElement>(
      `[data-tweaks-user-message="${CSS.escape(threadId)}"]`,
    ),
    (marker) =>
      marker.closest<HTMLElement>("[data-timeline-row-id]") ??
      marker.parentElement,
  ).filter((row): row is HTMLElement => row !== null);
  const anchor =
    rows[0] ?? document.querySelector<HTMLElement>("[data-timeline-row-id]");
  const container = anchor === null ? null : scrollParent(anchor);
  if (container === null) return;
  const top = container.getBoundingClientRect().top + JUMP_MARGIN_PX;
  const offsets = rows.map((row) => row.getBoundingClientRect().top - top);
  const target =
    step === 1
      ? rows[offsets.findIndex((offset) => offset > 1)]
      : rows[offsets.findLastIndex((offset) => offset < -1)];
  container.dispatchEvent(new WheelEvent("wheel"));
  if (target === undefined) {
    container.scrollTo({
      top: step === 1 ? container.scrollHeight : 0,
      behavior: "instant",
    });
  } else {
    container.scrollBy({
      top: target.getBoundingClientRect().top - top,
      behavior: "instant",
    });
  }
  container.dispatchEvent(new Event("scroll"));
}

const SORT_STYLE = `
[data-tweaks-table-sort] th { cursor: pointer; user-select: none; }
[data-tweaks-table-sort] th[data-tweaks-sort="ascending"]::after { content: " \\25B2"; font-size: 0.75em; }
[data-tweaks-table-sort] th[data-tweaks-sort="descending"]::after { content: " \\25BC"; font-size: 0.75em; }
`;

function SortableMarkdownFile({ Original }: PluginFileOpenerProps) {
  const rootRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    const root = rootRef.current;
    if (root === null) return;
    const sorts = new Map<HTMLTableElement, SortState>();
    const observer = new MutationObserver(() => {
      reapply();
    });
    const observe = () => {
      observer.observe(root, {
        childList: true,
        subtree: true,
        characterData: true,
      });
    };
    const reapply = () => {
      observer.disconnect();
      for (const [table, state] of sorts) {
        if (root.contains(table)) applyTableSort(table, state);
        else sorts.delete(table);
      }
      observe();
    };
    const onClick = (event: MouseEvent) => {
      if (!(event.target instanceof Element)) return;
      const cell = event.target.closest("th");
      const table = cell?.closest("table");
      if (cell == null || table == null || !root.contains(table)) return;
      if (event.target.closest("a, button") !== null) return;
      const state = nextSortState(sorts.get(table), cell.cellIndex);
      sorts.set(table, state);
      reapply();
    };
    root.addEventListener("click", onClick);
    observe();
    return () => {
      root.removeEventListener("click", onClick);
      observer.disconnect();
    };
  }, []);
  return (
    <div ref={rootRef} data-tweaks-table-sort="" className="contents">
      <style>{SORT_STYLE}</style>
      <Original />
    </div>
  );
}

export default definePluginApp((app) => {
  app.slots.experimental_appOverlay({
    id: "state",
    component: AppStateBridge,
  });

  app.slots.experimental_appOverlay({
    id: "archive-follower",
    component: ArchiveFollower,
  });

  app.composer.customize({
    id: "self-host",
    scopes: ["new-thread"],
    actions: [{ id: "self-host-default", component: SelfHostDefault }],
  });

  app.slots.experimental_threadRowMetadata<string | null>({
    id: "host",
    order: 0,
    useData: useOwnHostId,
    component: HostChip,
  });

  app.slots.experimental_messageMetadata({
    id: "user-message-marker",
    component: UserMessageMarker,
  });

  app.commands.register({
    id: "next-attention-thread",
    title: "Go to next thread needing attention",
    run: ({ threadId }) => {
      goToAttentionThread(threadId, 1);
    },
  });
  app.commands.register({
    id: "previous-attention-thread",
    title: "Go to previous thread needing attention",
    run: ({ threadId }) => {
      goToAttentionThread(threadId, -1);
    },
  });
  app.commands.register({
    id: "next-user-message",
    title: "Scroll to next user message",
    isAvailable: ({ threadId }) => threadId !== null,
    run: ({ threadId }) => {
      if (threadId !== null) jumpToUserMessage(threadId, 1);
    },
  });
  app.commands.register({
    id: "previous-user-message",
    title: "Scroll to previous user message",
    isAvailable: ({ threadId }) => threadId !== null,
    run: ({ threadId }) => {
      if (threadId !== null) jumpToUserMessage(threadId, -1);
    },
  });

  app.slots.fileOpener({
    id: "sortable-markdown",
    title: "Markdown with sortable tables",
    extensions: ["md", "markdown"],
    component: SortableMarkdownFile,
  });
});
