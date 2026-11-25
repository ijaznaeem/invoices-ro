# WhatsApp invoices through WhizText

Contract source: https://portal.whiztext.com/api-docs (read 25 November 2026).

1. Connect your WhatsApp account in the WhizText portal and create a **gateway** API key.
2. In Ledger, open Settings → WhatsApp settings and save the key. It is stored in
   encrypted device storage per Firebase account, excluded from Firestore, Ledger
   backups, and Android cloud/device-transfer backups. Re-enter it on a new device.
3. Open an invoice's PDF preview, tap the chat menu, and choose WhatsApp PDF or
   WhatsApp images. Review the country-code phone number and optional message, then send.

The app posts multipart/form-data to `https://api.whiztext.com/v1/send` with
`X-API-Key`, `to`, optional `message`, and exactly one uploaded `media` attachment.
It uses PDF or PNG and checks the documented 16 MiB limit before uploading.
Multi-page images are submitted sequentially, one request/message per page.

A successful response means accepted for background processing, including queued
submissions, rather than confirmed delivery. Check the portal's message history.
The app never automatically retries. After an interrupted/ambiguous request or a
partially submitted image set, it blocks another submission on that screen to
reduce duplicates. Verify history before starting a new send. The provider warns
that queued uploads can be lost after a disconnect/restart.

HTTP contract and failure handling are tested with mocked responses. Live delivery
requires your gateway key and connected account; tests do not message real recipients.
The public `/health` endpoint does not validate a key or WhatsApp connection.
