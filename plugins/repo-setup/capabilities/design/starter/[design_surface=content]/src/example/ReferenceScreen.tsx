import { useEffect, useState, type ComponentProps, type ReactNode } from "react";

import { Alert, AlertAction, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import {
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
} from "@/components/ui/empty";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { deleteItem, listItems, type Item, type Status } from "@/example/data";
import { formatDate } from "@/lib/format";
import { LABELS } from "@/lib/labels";

type Variant = ComponentProps<typeof Badge>["variant"];
// Each status keeps its own look. Never give two statuses the same variant to pass a check.
const STATUS: Record<Status, { label: string; variant: Variant }> = {
  active: { label: LABELS.statusActive, variant: "secondary" },
  overdue: { label: LABELS.statusOverdue, variant: "destructive" },
};

function Notice(props: { title: string; detail: string; action: string; onAction: () => void }) {
  return (
    <Empty>
      <EmptyHeader>
        <EmptyTitle>{props.title}</EmptyTitle>
        <EmptyDescription>{props.detail}</EmptyDescription>
      </EmptyHeader>
      <EmptyContent>
        <Button onClick={props.onAction}>{props.action}</Button>
      </EmptyContent>
    </Empty>
  );
}

function ConfirmDelete(props: {
  item: Item | null;
  saving: boolean;
  failed: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Dialog
      open={props.item !== null}
      onOpenChange={(open) => {
        if (!open && !props.saving) props.onCancel();
      }}
    >
      <DialogContent showCloseButton={false}>
        <DialogHeader>
          <DialogTitle>{props.item ? LABELS.deleteItem(props.item.name) : ""}</DialogTitle>
          <DialogDescription>{LABELS.deleteDetail}</DialogDescription>
        </DialogHeader>
        {props.failed && props.item && (
          <Alert variant="destructive">
            <AlertTitle>{LABELS.deleteFailed(props.item.name)}</AlertTitle>
            <AlertDescription>{LABELS.errorDetail}</AlertDescription>
          </Alert>
        )}
        <DialogFooter>
          <DialogClose render={<Button variant="outline" disabled={props.saving} />}>
            {LABELS.cancel}
          </DialogClose>
          <Button variant="destructive" disabled={props.saving} onClick={props.onConfirm}>
            {props.saving ? LABELS.saving : LABELS.deleteAction}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

// Every state follows from a request or from the user, never from a prop or the address.
export function ReferenceScreen() {
  // The list request: pending while items is null, then the items or a failure.
  const [items, setItems] = useState<Item[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  // What the user is doing: filtering, or deleting one item.
  const [query, setQuery] = useState("");
  const [target, setTarget] = useState<Item | null>(null);
  const [saving, setSaving] = useState(false);
  const [deleteFailed, setDeleteFailed] = useState(false);

  useEffect(() => {
    let current = true; // ignore an answer that arrives after the screen has moved on
    listItems().then(
      (found) => current && setItems(found),
      () => current && setFailed(true),
    );
    return () => {
      current = false;
    };
  }, [attempt]);

  function reload() {
    setItems(null);
    setFailed(false);
    setAttempt((n) => n + 1);
  }

  function closeDialog() {
    setTarget(null);
    setDeleteFailed(false);
  }

  async function confirmDelete() {
    if (!target) return;
    setSaving(true);
    setDeleteFailed(false);
    try {
      await deleteItem(target.id);
      setItems((current) => current?.filter((item) => item.id !== target.id) ?? null);
      setTarget(null);
    } catch {
      setDeleteFailed(true);
    } finally {
      setSaving(false);
    }
  }

  const shown = (items ?? []).filter((item) =>
    item.name.toLowerCase().includes(query.toLowerCase()),
  );

  let body: ReactNode;
  if (failed) {
    body = (
      <Alert variant="destructive">
        <AlertTitle>{LABELS.errorTitle}</AlertTitle>
        <AlertDescription>{LABELS.errorDetail}</AlertDescription>
        <AlertAction>
          <Button variant="outline" size="sm" onClick={reload}>
            {LABELS.retry}
          </Button>
        </AlertAction>
      </Alert>
    );
  } else if (items === null) {
    body = (
      <div role="status" className="flex flex-col gap-3">
        <span className="sr-only">{LABELS.loading}</span>
        <Skeleton className="h-6 w-1/2" />
        <Skeleton className="h-4 w-full" />
        <Skeleton className="h-4 w-full" />
      </div>
    );
  } else if (items.length === 0) {
    body = (
      <Notice
        title={LABELS.emptyTitle}
        detail={LABELS.emptyDetail}
        action={LABELS.emptyAction}
        onAction={reload}
      />
    );
  } else if (shown.length === 0) {
    body = (
      <Notice
        title={LABELS.noResultsTitle}
        detail={LABELS.noResultsDetail}
        action={LABELS.noResultsAction}
        onAction={() => setQuery("")}
      />
    );
  } else {
    body = (
      <div className="flex flex-col gap-4">
        {shown.map((item) => (
          <Card key={item.id}>
            <CardHeader>
              <CardTitle>{item.name}</CardTitle>
              <CardDescription>{formatDate(item.date)}</CardDescription>
              <CardAction>
                <Button
                  variant="outline"
                  size="sm"
                  aria-label={LABELS.deleteItem(item.name)}
                  onClick={() => setTarget(item)}
                >
                  {LABELS.deleteAction}
                </Button>
              </CardAction>
            </CardHeader>
            <CardContent>
              <div className="flex flex-col gap-2">
                <Badge variant={STATUS[item.status].variant}>{STATUS[item.status].label}</Badge>
                <p className="text-base">{item.body}</p>
              </div>
            </CardContent>
          </Card>
        ))}
      </div>
    );
  }

  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-6 p-6">
      <h1 className="text-2xl font-semibold">{LABELS.screenTitle}</h1>
      {items && items.length > 0 && (
        <div className="flex flex-col gap-2">
          <Label htmlFor="filter">{LABELS.filter}</Label>
          <Input
            id="filter"
            type="search"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
          />
        </div>
      )}
      {body}
      <ConfirmDelete
        item={target}
        saving={saving}
        failed={deleteFailed}
        onConfirm={confirmDelete}
        onCancel={closeDialog}
      />
    </main>
  );
}
