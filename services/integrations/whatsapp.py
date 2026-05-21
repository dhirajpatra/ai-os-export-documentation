import os
import httpx
from datetime import datetime
from services.api.main import cfg  # Read from baseline runtime configuration context

class WhatsAppService:

    @staticmethod
    async def send_text(to: str, body: str) -> dict:
        provider = os.getenv("WHATSAPP_PROVIDER", cfg.WHATSAPP_PROVIDER).lower()
        if provider == "twilio":
            return await WhatsAppService._send_twilio_text(to, body)
        return await WhatsAppService._send_meta_text(to, body)

    @staticmethod
    async def send_document(to: str, doc_url: str, filename: str, caption: str = "") -> dict:
        provider = os.getenv("WHATSAPP_PROVIDER", cfg.WHATSAPP_PROVIDER).lower()
        if provider == "twilio":
            return await WhatsAppService._send_twilio_document(to, doc_url, filename, caption)
        return await WhatsAppService._send_meta_document(to, doc_url, filename, caption)

    @staticmethod
    async def _send_meta_text(to: str, body: str) -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{cfg.WHATSAPP_API_URL}/{os.getenv('WHATSAPP_PHONE_ID')}/messages",
                headers={"Authorization": f"Bearer {os.getenv('WHATSAPP_TOKEN')}"},
                json={
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "text",
                    "text": {"body": body},
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    async def _send_meta_document(to: str, doc_url: str, filename: str, caption: str = "") -> dict:
        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"{cfg.WHATSAPP_API_URL}/{os.getenv('WHATSAPP_PHONE_ID')}/messages",
                headers={"Authorization": f"Bearer {os.getenv('WHATSAPP_TOKEN')}"},
                json={
                    "messaging_product": "whatsapp",
                    "to": to,
                    "type": "document",
                    "document": {"link": doc_url, "filename": filename, "caption": caption},
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    async def _send_twilio_text(to: str, body: str) -> dict:
        account_sid = WhatsAppService._env("TWILIO_ACCOUNT_SID")
        auth_token = WhatsAppService._env("TWILIO_AUTH_TOKEN")
        from_number = WhatsAppService._twilio_whatsapp_number(WhatsAppService._env("TWILIO_PHONE_NUMBER"))

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json",
                auth=(account_sid, auth_token),
                data={
                    "From": from_number,
                    "To": WhatsAppService._twilio_whatsapp_number(to),
                    "Body": body,
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    async def _send_twilio_document(to: str, doc_url: str, filename: str, caption: str = "") -> dict:
        account_sid = WhatsAppService._env("TWILIO_ACCOUNT_SID")
        auth_token = WhatsAppService._env("TWILIO_AUTH_TOKEN")
        from_number = WhatsAppService._twilio_whatsapp_number(WhatsAppService._env("TWILIO_PHONE_NUMBER"))
        body = caption or filename

        async with httpx.AsyncClient() as client:
            resp = await client.post(
                f"https://api.twilio.com/2010-04-01/Accounts/{account_sid}/Messages.json",
                auth=(account_sid, auth_token),
                data={
                    "From": from_number,
                    "To": WhatsAppService._twilio_whatsapp_number(to),
                    "Body": body,
                    "MediaUrl": doc_url,
                },
            )
            resp.raise_for_status()
            return resp.json()

    @staticmethod
    def parse_meta_inbound(payload: dict) -> list[dict]:
        messages = []
        for entry in payload.get("entry", []):
            for change in entry.get("changes", []):
                value = change.get("value", {})
                for msg in value.get("messages", []):
                    msg_type = msg.get("type")
                    doc = msg.get("document", {})
                    messages.append({
                        "from":      msg.get("from"),
                        "wa_msg_id": msg.get("id"),
                        "type":      msg_type,
                        "text":      msg.get("text", {}).get("body", ""),
                        "timestamp": msg.get("timestamp"),
                        "contact":   value.get("contacts", [{}])[0],
                        "media_id":  doc.get("id"),
                        "mime_type": doc.get("mime_type", "application/pdf"),
                        "filename":  doc.get("filename"),
                    })
        return messages

    @staticmethod
    def parse_twilio_inbound(form: dict) -> list[dict]:
        text = form.get("Body", "")
        media_urls = [form.get(f"MediaUrl{i}") for i in range(int(form.get("NumMedia", "0") or 0)) if form.get(f"MediaUrl{i}")]
        return [{
            "from": WhatsAppService._strip_twilio_whatsapp_prefix(form.get("From", "")),
            "wa_msg_id": form.get("MessageSid") or form.get("SmsSid"),
            "type": "document" if media_urls else "text",
            "text": text,
            "timestamp": datetime.utcnow().isoformat(),
            "contact": {
                "profile": {"name": form.get("ProfileName", "")},
                "wa_id": WhatsAppService._strip_twilio_whatsapp_prefix(form.get("WaId", "")),
            },
            "media_urls": media_urls,
            "provider": "twilio",
        }]

    @staticmethod
    def _twilio_whatsapp_number(number: str) -> str:
        return number if number.startswith("whatsapp:") else f"whatsapp:{number}"

    @staticmethod
    def _strip_twilio_whatsapp_prefix(number: str) -> str:
        return number.removeprefix("whatsapp:")

    @staticmethod
    def _env(name: str) -> str:
        legacy_name = name.replace("TWILIO", "TWIlIO")
        value = os.getenv(name) or os.getenv(legacy_name) or getattr(cfg, name, "")
        if not value:
            raise RuntimeError(f"{name} is required for Twilio WhatsApp")
        return value

    @staticmethod
    async def download_media(media_id: str) -> bytes:
        token = os.getenv("WHATSAPP_TOKEN", cfg.WHATSAPP_TOKEN)
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.get(f"{cfg.WHATSAPP_API_URL}/{media_id}", headers={"Authorization": f"Bearer {token}"})
            resp.raise_for_status()
            download_url = resp.json()["url"]

        async with httpx.AsyncClient(timeout=60) as client:
            resp = await client.get(download_url, headers={"Authorization": f"Bearer {token}"})
            resp.raise_for_status()
            return resp.content