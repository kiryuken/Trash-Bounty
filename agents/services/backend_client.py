from __future__ import annotations

from io import BytesIO
from typing import Any

import httpx


class BackendClient:
    def __init__(self, base_url: str, internal_secret: str) -> None:
        self._client = httpx.AsyncClient(
            base_url=base_url.rstrip("/"),
            timeout=20.0,
            headers={"X-Internal-Secret": internal_secret},
        )

    async def close(self) -> None:
        await self._client.aclose()

    async def link_account(self, token: str, telegram_chat_id: str) -> dict[str, Any]:
        response = await self._client.post(
            "/v1/telegram/link",
            headers={},
            json={
                "token": token,
                "telegram_chat_id": telegram_chat_id,
            },
        )
        return self._unwrap(response)

    async def unlink_account(self, telegram_chat_id: str) -> dict[str, Any]:
        response = await self._client.delete(f"/internal/telegram/{telegram_chat_id}/link")
        return self._unwrap(response)

    async def get_bounties(self, telegram_chat_id: str, limit: int = 5) -> dict[str, list[dict[str, Any]]]:
        response = await self._client.get(
            f"/internal/telegram/{telegram_chat_id}/bounties",
            params={"limit": limit},
        )
        return self._unwrap(response)

    async def get_status(self, telegram_chat_id: str) -> dict[str, Any]:
        response = await self._client.get(f"/internal/telegram/{telegram_chat_id}/status")
        return self._unwrap(response)

    async def get_recommended(self, telegram_chat_id: str, lat: float, lon: float) -> list[dict[str, Any]]:
        response = await self._client.get(
            f"/internal/telegram/{telegram_chat_id}/recommended",
            params={"lat": lat, "lon": lon, "limit": 5},
        )
        return self._unwrap(response)

    async def support_chat(self, messages: list[dict[str, str]]) -> str:
        response = await self._client.post(
            "/internal/telegram/support",
            json={"messages": messages},
        )
        data = self._unwrap(response)
        return str(data.get("reply", "")).strip()

    async def create_report(
        self,
        telegram_chat_id: str,
        image_bytes: bytes,
        location_text: str,
        lat: float,
        lon: float,
        filename: str = "report.jpg",
    ) -> dict[str, Any]:
        response = await self._client.post(
            f"/internal/telegram/{telegram_chat_id}/report",
            data={
                "location_text": location_text,
                "latitude": str(lat),
                "longitude": str(lon),
            },
            files={
                "image": (filename, BytesIO(image_bytes), "image/jpeg"),
            },
        )
        return self._unwrap(response)

    async def list_reports(self, telegram_chat_id: str, limit: int = 5) -> list[dict[str, Any]]:
        response = await self._client.get(
            f"/internal/telegram/{telegram_chat_id}/reports",
            params={"limit": limit},
        )
        return self._unwrap(response)

    async def get_report_status(self, telegram_chat_id: str, report_id: str) -> dict[str, Any]:
        response = await self._client.get(f"/internal/telegram/{telegram_chat_id}/reports/{report_id}")
        return self._unwrap(response)

    def _unwrap(self, response: httpx.Response) -> Any:
        payload = response.json()
        if response.is_success and payload.get("success") is True:
            return payload.get("data")

        message = payload.get("error") if isinstance(payload, dict) else response.text
        raise RuntimeError(message or "backend request failed")