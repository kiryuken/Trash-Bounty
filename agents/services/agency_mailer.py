from __future__ import annotations

import asyncio
import smtplib
from dataclasses import dataclass
from email.message import EmailMessage
from pathlib import PurePosixPath
from textwrap import dedent
from urllib.parse import urljoin

import httpx
from pydantic import BaseModel


class AgencyEscalationPayload(BaseModel):
    report_id: str
    report_status: str
    reporter_id: str
    reporter_name: str
    reporter_email: str
    location_text: str
    latitude: float
    longitude: float
    urgency_reason: str
    requested_at: str
    image_url: str
    waste_type: str | None = None
    severity: int | None = None
    ai_reasoning: str | None = None
    ai_confidence: float | None = None
    estimated_weight_kg: float | None = None
    report_created_at: str | None = None


@dataclass(slots=True)
class AgencyMailer:
    backend_base_url: str
    recipient: str
    smtp_host: str
    smtp_port: int
    smtp_username: str
    smtp_password: str
    smtp_from: str
    smtp_use_tls: bool = True

    async def send_agency_escalation(self, payload: AgencyEscalationPayload) -> None:
        attachment = await self._download_attachment(payload)
        await asyncio.to_thread(self._send_email, payload, attachment)

    async def _download_attachment(self, payload: AgencyEscalationPayload) -> tuple[str, bytes, str]:
        image_url = payload.image_url.strip()
        if not image_url:
            raise RuntimeError("image_url laporan tidak tersedia")

        backend_base = self.backend_base_url.rstrip("/") + "/"
        relative_path = image_url if image_url.startswith("/") else image_url.lstrip("/")
        download_url = image_url if image_url.startswith("http://") or image_url.startswith("https://") else urljoin(backend_base, relative_path)

        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.get(download_url)
            response.raise_for_status()

        filename = PurePosixPath(response.request.url.path).name or f"report-{payload.report_id}.jpg"
        content_type = response.headers.get("content-type", "application/octet-stream")
        return filename, response.content, content_type

    def _send_email(self, payload: AgencyEscalationPayload, attachment: tuple[str, bytes, str]) -> None:
        if not self.smtp_host or not self.smtp_from or not self.recipient:
            raise RuntimeError("konfigurasi email dinas belum lengkap")

        msg = EmailMessage()
        msg["Subject"] = f"[TrashBounty] Eskalasi laporan {payload.report_id} - {payload.location_text}"
        msg["From"] = self.smtp_from
        msg["To"] = self.recipient
        msg["Reply-To"] = payload.reporter_email
        msg.set_content(self._build_body(payload))

        filename, file_bytes, content_type = attachment
        maintype, _, subtype = content_type.partition("/")
        if not maintype or not subtype:
            maintype = "application"
            subtype = "octet-stream"
        msg.add_attachment(file_bytes, maintype=maintype, subtype=subtype, filename=filename)

        with smtplib.SMTP(self.smtp_host, self.smtp_port, timeout=20) as server:
            if self.smtp_use_tls:
                server.starttls()
            if self.smtp_username:
                server.login(self.smtp_username, self.smtp_password)
            server.send_message(msg)

    def _build_body(self, payload: AgencyEscalationPayload) -> str:
        severity = str(payload.severity) if payload.severity is not None else "-"
        waste_type = payload.waste_type or "-"
        ai_confidence = f"{payload.ai_confidence * 100:.0f}%" if payload.ai_confidence is not None else "-"
        estimated_weight = f"{payload.estimated_weight_kg:.1f} kg" if payload.estimated_weight_kg is not None else "-"
        reasoning = payload.ai_reasoning.strip() if payload.ai_reasoning else "-"

        return dedent(
            f"""
            Kepada Dinas Lingkungan Hidup,

            Berikut laporan warga yang memerlukan perhatian lebih lanjut melalui aplikasi TrashBounty.

            Data pelapor:
            - Nama: {payload.reporter_name}
            - Email: {payload.reporter_email}
            - User ID: {payload.reporter_id}

            Data laporan:
            - Report ID: {payload.report_id}
            - Status report saat eskalasi: {payload.report_status}
            - Lokasi: {payload.location_text}
            - Koordinat: {payload.latitude}, {payload.longitude}
            - Dibuat pada: {payload.report_created_at or '-'}
            - Diminta eskalasi pada: {payload.requested_at}

            Ringkasan analisis Lumi:
            - Jenis sampah: {waste_type}
            - Severity: {severity}
            - Akurasi AI: {ai_confidence}
            - Estimasi berat: {estimated_weight}
            - Catatan AI: {reasoning}

            Alasan urgensi dari pengguna:
            {payload.urgency_reason}

            Foto laporan terlampir pada email ini.

            Hormat kami,
            TrashBounty
            """
        ).strip()