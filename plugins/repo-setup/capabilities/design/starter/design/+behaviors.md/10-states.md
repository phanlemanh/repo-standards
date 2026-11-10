# Screen behaviors

One answer for each case. Use it instead of inventing another.

## States

- **Loading:** show the shape of the coming content, not a spinner, with `Skeleton`.
- **Empty:** say nothing exists yet and offer the first action, with `Empty` and a `Button`.
- **Error:** say what failed and what to try next, with `Alert` and `variant="destructive"`.
- **No results:** say the search found nothing and offer to clear it, with `Empty` and a `Button`.
- **Saving:** keep the form on screen and disable its submit control, with `Button` and `disabled`.
- **Confirm delete:** name the thing being deleted and ask before acting, with `Dialog`.
