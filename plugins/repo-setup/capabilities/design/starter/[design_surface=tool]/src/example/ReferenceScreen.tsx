import { useState, type ComponentProps, type ReactNode } from "react";

import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
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
import { Skeleton } from "@/components/ui/skeleton";
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table";
import { formatDate, formatMoney } from "@/lib/format";
import { LABELS } from "@/lib/labels";

export type ScreenState =
  "ready" | "loading" | "empty" | "error" | "no-results" | "saving" | "confirm-delete";

type Status = "active" | "pending" | "overdue";
type Row = { name: string; status: Status; date: Date; total: number };

type Variant = ComponentProps<typeof Badge>["variant"];
// Each status keeps its own look. Never give two statuses the same variant to pass a check.
const STATUS: Record<Status, { label: string; variant: Variant }> = {
  active: { label: LABELS.statusActive, variant: "default" },
  pending: { label: LABELS.statusPending, variant: "outline" },
  overdue: { label: LABELS.statusOverdue, variant: "destructive" },
};

const ROWS: Row[] = [
  { name: LABELS.sampleFirstName, status: "active", date: new Date(2026, 0, 15), total: 1200 },
  { name: LABELS.sampleSecondName, status: "pending", date: new Date(2026, 1, 3), total: 350 },
  { name: LABELS.sampleThirdName, status: "overdue", date: new Date(2026, 2, 9), total: 90 },
];

// Stands in for the real request. Replace it with the call to your API.
function removeRow(): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, 600));
}

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
  row: Row | null;
  saving: boolean;
  onConfirm: () => void;
  onCancel: () => void;
}) {
  return (
    <Dialog
      open={props.row !== null}
      onOpenChange={(open) => {
        if (!open && !props.saving) props.onCancel();
      }}
    >
      <DialogContent showCloseButton={false}>
        <DialogHeader>
          <DialogTitle>{props.row ? LABELS.deleteItem(props.row.name) : ""}</DialogTitle>
          <DialogDescription>{LABELS.deleteDetail}</DialogDescription>
        </DialogHeader>
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

export function ReferenceScreen({ state }: { state: ScreenState }) {
  const asksDelete = state === "confirm-delete" || state === "saving";
  const [view, setView] = useState<ScreenState>(asksDelete ? "ready" : state);
  const [rows, setRows] = useState<Row[]>(state === "empty" ? [] : ROWS);
  const [target, setTarget] = useState<Row | null>(asksDelete ? (ROWS[0] ?? null) : null);
  const [saving, setSaving] = useState(state === "saving");

  async function confirmDelete() {
    if (!target) return;
    setSaving(true);
    await removeRow();
    setRows((current) => current.filter((row) => row !== target));
    setSaving(false);
    setTarget(null);
  }

  let body: ReactNode;
  if (view === "loading") {
    body = (
      <div role="status" className="flex flex-col gap-2">
        <span className="sr-only">{LABELS.loading}</span>
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-8 w-full" />
      </div>
    );
  } else if (view === "error") {
    body = (
      <Alert variant="destructive">
        <AlertTitle>{LABELS.errorTitle}</AlertTitle>
        <AlertDescription>{LABELS.errorDetail}</AlertDescription>
      </Alert>
    );
  } else if (view === "no-results") {
    body = (
      <Notice
        title={LABELS.noResultsTitle}
        detail={LABELS.noResultsDetail}
        action={LABELS.noResultsAction}
        onAction={() => setView("ready")}
      />
    );
  } else if (rows.length === 0) {
    body = (
      <Notice
        title={LABELS.emptyTitle}
        detail={LABELS.emptyDetail}
        action={LABELS.emptyAction}
        onAction={() => {
          setRows(ROWS);
          setView("ready");
        }}
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
          {rows.map((row) => (
            <TableRow key={row.name}>
              <TableCell>{row.name}</TableCell>
              <TableCell>
                <Badge variant={STATUS[row.status].variant}>{STATUS[row.status].label}</Badge>
              </TableCell>
              <TableCell>{formatDate(row.date)}</TableCell>
              <TableCell>{formatMoney(row.total)}</TableCell>
              <TableCell>
                <Button
                  variant="outline"
                  size="sm"
                  aria-label={LABELS.deleteItem(row.name)}
                  onClick={() => setTarget(row)}
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
      {body}
      <ConfirmDelete
        row={target}
        saving={saving}
        onConfirm={confirmDelete}
        onCancel={() => setTarget(null)}
      />
    </main>
  );
}
