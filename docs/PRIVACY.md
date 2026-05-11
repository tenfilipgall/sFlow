# SFlow Privacy

SFlow never sends your messages, channel names, document contents, or anything you type.

When you open an app SFlow has not seen before, SFlow sends to our backend:
- The app's bundle identifier (e.g. `com.linear.electron`)
- The app's name and version
- The app's menu bar structure (e.g. `File > New Issue [cmd+n]`)
- A list of public button and link labels visible in the UI (e.g. `New issue`, `Inbox`) — filtered to exclude likely content such as channel names (`#…`), usernames (`@…`), email addresses, and human-name patterns

We never send:
- Text from any text field, message, or document you are editing
- Window titles, file names, or URLs you have open
- Telemetry tied to a user identity — discovery requests are anonymous

For apps where the UI is mostly content (Mail, Messages, 1Password, WhatsApp), SFlow only sends the menu bar.

Pro users can supply their own Anthropic API key in Settings; in that mode, discovery requests bypass our backend entirely.
