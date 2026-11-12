# Screen behaviors

One answer for each case. Use it instead of inventing another.

## States

A state appears because of a real condition: a pending or failed request, an empty result, a
filter with no match, a user action. Never because of a switch: a prop or URL value that exists
only to pick the state. Tests choose the condition through the data source.

- **Loading:** show the shape of the coming content, not a spinner, with `Skeleton`.
- **Empty:** say nothing exists yet and offer the first action, with `Empty` and a `Button`.
- **Error:** say what failed and offer to try again, with `Alert` and `variant="destructive"`.
- **No results:** say the search found nothing and offer to clear it, with `Empty` and a `Button`.
- **Saving:** keep the form on screen and disable its submit control, with `Button` and `disabled`.
- **Confirm delete:** name the thing being deleted and ask before acting, with `Dialog`.
- **Delete failed:** keep the dialog and the item, and say it was not deleted, with `Alert`.
