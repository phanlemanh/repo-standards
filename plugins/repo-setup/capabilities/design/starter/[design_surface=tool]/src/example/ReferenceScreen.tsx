import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
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

export type ScreenState = "ready" | "loading" | "empty" | "error" | "no-results";

const ROWS = [
  { name: LABELS.sampleFirstName, date: new Date(2026, 0, 15), total: 1200 },
  { name: LABELS.sampleSecondName, date: new Date(2026, 1, 3), total: 350 },
];

function Notice({ title, detail, action }: { title: string; detail: string; action: string }) {
  return (
    <Empty>
      <EmptyHeader>
        <EmptyTitle>{title}</EmptyTitle>
        <EmptyDescription>{detail}</EmptyDescription>
      </EmptyHeader>
      <EmptyContent>
        <Button>{action}</Button>
      </EmptyContent>
    </Empty>
  );
}

function Body({ state }: { state: ScreenState }) {
  if (state === "loading") {
    return (
      <div role="status" className="flex flex-col gap-2">
        <span className="sr-only">{LABELS.loading}</span>
        <Skeleton className="h-8 w-full" />
        <Skeleton className="h-8 w-full" />
      </div>
    );
  }
  if (state === "error") {
    return (
      <Alert variant="destructive">
        <AlertTitle>{LABELS.errorTitle}</AlertTitle>
        <AlertDescription>{LABELS.errorDetail}</AlertDescription>
      </Alert>
    );
  }
  if (state === "empty") {
    return (
      <Notice title={LABELS.emptyTitle} detail={LABELS.emptyDetail} action={LABELS.emptyAction} />
    );
  }
  if (state === "no-results") {
    return (
      <Notice
        title={LABELS.noResultsTitle}
        detail={LABELS.noResultsDetail}
        action={LABELS.noResultsAction}
      />
    );
  }
  return (
    <Table>
      <TableHeader>
        <TableRow>
          <TableHead>{LABELS.columnName}</TableHead>
          <TableHead>{LABELS.columnDate}</TableHead>
          <TableHead>{LABELS.columnTotal}</TableHead>
        </TableRow>
      </TableHeader>
      <TableBody>
        {ROWS.map((row) => (
          <TableRow key={row.name}>
            <TableCell>{row.name}</TableCell>
            <TableCell>{formatDate(row.date)}</TableCell>
            <TableCell>{formatMoney(row.total)}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}

export function ReferenceScreen({ state }: { state: ScreenState }) {
  return (
    <main className="mx-auto flex max-w-5xl flex-col gap-4 p-6 text-sm">
      <h1 className="text-lg font-semibold">{LABELS.screenTitle}</h1>
      <Body state={state} />
    </main>
  );
}
