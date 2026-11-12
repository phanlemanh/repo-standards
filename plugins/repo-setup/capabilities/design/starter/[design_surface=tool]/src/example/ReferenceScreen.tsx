import { useEffect, useState, type ReactNode } from "react";

import { Alert, AlertAction, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
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
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { createItem, deleteItem, listItems, type Item } from "@/example/data";
import { formatDate, formatMoney } from "@/lib/format";
import { LABELS } from "@/lib/labels";

const STATUS = {
  active: { label: LABELS.statusActive, variant: "default" },
  pending: { label: LABELS.statusPending, variant: "outline" },
  overdue: { label: LABELS.statusOverdue, variant: "destructive" },
} as const;

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

export function ReferenceScreen() {
  const [items, setItems] = useState<Item[] | null>(null);
  const [failed, setFailed] = useState(false);
  const [attempt, setAttempt] = useState(0);
  const [query, setQuery] = useState("");
  const [asking, setAsking] = useState(false);
  const [target, setTarget] = useState<Item | null>(null);
  const [saving, setSaving] = useState(false);
  const [deleteFailed, setDeleteFailed] = useState(false);
  useEffect(() => {
    let current = true;
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

  function addFirst() {
    setItems(null);
    void createItem().then(reload, reload);
  }

  function askDelete(item: Item) {
    setTarget(item);
    setDeleteFailed(false);
    setAsking(true);
  }

  async function confirmDelete() {
    if (!target) return;
    setSaving(true);
    setDeleteFailed(false);
    try {
      await deleteItem(target.id);
      setItems((current) => current?.filter((item) => item.id !== target.id) ?? null);
      setAsking(false);
    } catch {
      setDeleteFailed(true);
    }
    setSaving(false);
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
      <div role="status" className="flex flex-col gap-2">
        <span className="sr-only">{LABELS.loading}</span>
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-8 w-full" />
      </div>
    );
  } else if (items.length === 0) {
    body = (
      <Notice
        title={LABELS.emptyTitle}
        detail={LABELS.emptyDetail}
        action={LABELS.emptyAction}
        onAction={addFirst}
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
      <Table aria-label={LABELS.tableName}>
        <TableHeader>
          <TableRow>
            <TableHead>{LABELS.columnName}</TableHead>
            <TableHead>{LABELS.columnStatus}</TableHead>
            <TableHead>{LABELS.columnDate}</TableHead>
            <TableHead>{LABELS.columnTotal}</TableHead>
            <TableHead>{LABELS.columnActions}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {shown.map((item) => (
            <TableRow key={item.id}>
              <TableCell>{item.name}</TableCell>
              <TableCell>
                <Badge variant={STATUS[item.status].variant}>{STATUS[item.status].label}</Badge>
              </TableCell>
              <TableCell>{formatDate(item.date)}</TableCell>
              <TableCell>{formatMoney(item.total)}</TableCell>
              <TableCell>
                <Button
                  variant="outline"
                  size="sm"
                  aria-label={LABELS.deleteItem(item.name)}
                  onClick={() => askDelete(item)}
                >
                  {LABELS.deleteAction}
                </Button>
              </TableCell>
            </TableRow>
          ))}
        </TableBody>
      </Table>
    );
  }

  return (
    <main className="mx-auto flex max-w-5xl flex-col gap-4 p-6 text-sm">
      <h1 className="text-lg font-semibold">{LABELS.screenTitle}</h1>
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
      <Dialog
        open={asking}
        onOpenChange={(open) => {
          if (!open && !saving) setAsking(false);
        }}
      >
        <DialogContent showCloseButton={false}>
          <DialogHeader>
            <DialogTitle>{target ? LABELS.deleteItem(target.name) : ""}</DialogTitle>
            <DialogDescription>{LABELS.deleteDetail}</DialogDescription>
          </DialogHeader>
          {deleteFailed && target && (
            <Alert variant="destructive">
              <AlertTitle>{LABELS.deleteFailed(target.name)}</AlertTitle>
              <AlertDescription>{LABELS.errorDetail}</AlertDescription>
            </Alert>
          )}
          <DialogFooter>
            <DialogClose render={<Button variant="outline" disabled={saving} />}>
              {LABELS.cancel}
            </DialogClose>
            <Button variant="destructive" disabled={saving} onClick={confirmDelete}>
              {saving ? LABELS.saving : LABELS.deleteAction}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </main>
  );
}
