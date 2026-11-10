import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import {
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyTitle,
} from "@/components/ui/empty";
import { Skeleton } from "@/components/ui/skeleton";
import { formatDate } from "@/lib/format";
import { LABELS } from "@/lib/labels";

export type ScreenState = "ready" | "loading" | "empty" | "error" | "no-results";

const ENTRIES = [
  { title: LABELS.sampleFirstName, date: new Date(2026, 0, 15), body: LABELS.sampleFirstBody },
  { title: LABELS.sampleSecondName, date: new Date(2026, 1, 3), body: LABELS.sampleSecondBody },
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
      <div role="status" className="flex flex-col gap-3">
        <span className="sr-only">{LABELS.loading}</span>
        <Skeleton className="h-6 w-1/2" />
        <Skeleton className="h-4 w-full" />
        <Skeleton className="h-4 w-full" />
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
    <div className="flex flex-col gap-4">
      {ENTRIES.map((entry) => (
        <Card key={entry.title}>
          <CardHeader>
            <CardTitle>{entry.title}</CardTitle>
            <CardDescription>{formatDate(entry.date)}</CardDescription>
          </CardHeader>
          <CardContent>
            <p>{entry.body}</p>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

export function ReferenceScreen({ state }: { state: ScreenState }) {
  return (
    <main className="mx-auto flex max-w-2xl flex-col gap-6 p-6 text-base">
      <h1 className="text-2xl font-semibold">{LABELS.screenTitle}</h1>
      <Body state={state} />
    </main>
  );
}
