from __future__ import annotations

import asyncio
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from telegram.ext import Application, ApplicationBuilder
import uvicorn

from bot.handlers import register_handlers
from services.backend_client import BackendClient
from services.agency_mailer import AgencyEscalationPayload, AgencyMailer
from services.report_generator import generate_full_report


def load_local_env() -> None:
    loaded = load_dotenv(".env.local")
    loaded = load_dotenv(".env") or loaded
    if not loaded:
        print("WARN: .env.local or .env file not found, using system env")


load_local_env()

DEFAULT_TRASHBOUNTY_API_URL = "http://localhost:8080"


class Settings(BaseModel):
    telegram_bot_token: str
    trashbounty_api_url: str
    trashbounty_internal_secret: str
    agency_report_recipient: str
    smtp_host: str
    smtp_port: int = 587
    smtp_username: str
    smtp_password: str
    smtp_from: str
    smtp_use_tls: bool = True
    port: int = 8000


class NotifyPayload(BaseModel):
    telegram_chat_id: str
    message: str


def load_settings() -> Settings:
    return Settings(
        telegram_bot_token=os.getenv("TELEGRAM_BOT_TOKEN", ""),
        trashbounty_api_url=os.getenv("TRASHBOUNTY_API_URL", DEFAULT_TRASHBOUNTY_API_URL),
        trashbounty_internal_secret=os.getenv("TRASHBOUNTY_INTERNAL_SECRET", ""),
        agency_report_recipient=os.getenv("AGENCY_REPORT_RECIPIENT", "dinaslh@jakarta.go.id"),
        smtp_host=os.getenv("SMTP_HOST", ""),
        smtp_port=int(os.getenv("SMTP_PORT", "587")),
        smtp_username=os.getenv("SMTP_USERNAME", ""),
        smtp_password=os.getenv("SMTP_PASSWORD", ""),
        smtp_from=os.getenv("SMTP_FROM", ""),
        smtp_use_tls=os.getenv("SMTP_USE_TLS", "true").strip().lower() in {"1", "true", "yes", "on"},
        port=int(os.getenv("PORT", "8000")),
    )


settings = load_settings()
backend_client = BackendClient(settings.trashbounty_api_url, settings.trashbounty_internal_secret)
agency_mailer = AgencyMailer(
    backend_base_url=settings.trashbounty_api_url,
    recipient=settings.agency_report_recipient,
    smtp_host=settings.smtp_host,
    smtp_port=settings.smtp_port,
    smtp_username=settings.smtp_username,
    smtp_password=settings.smtp_password,
    smtp_from=settings.smtp_from,
    smtp_use_tls=settings.smtp_use_tls,
)
telegram_app: Application | None = None
telegram_task: asyncio.Task | None = None


async def _run_telegram_bot(application: Application) -> None:
    await application.initialize()
    await application.start()
    if application.updater is None:
        raise RuntimeError("telegram updater tidak tersedia")

    await application.updater.start_polling(drop_pending_updates=True)
    try:
        while True:
            await asyncio.sleep(3600)
    finally:
        await application.updater.stop()
        await application.stop()
        await application.shutdown()


@asynccontextmanager
async def lifespan(_: FastAPI):
    global telegram_app, telegram_task

    bot_token = settings.telegram_bot_token.strip()
    if bot_token:
        telegram_app = ApplicationBuilder().token(bot_token).build()
        register_handlers(telegram_app, backend_client)
        telegram_task = asyncio.create_task(_run_telegram_bot(telegram_app))

    try:
        yield
    finally:
        if telegram_task is not None:
            telegram_task.cancel()
            try:
                await telegram_task
            except asyncio.CancelledError:
                pass
        await backend_client.close()


app = FastAPI(title="TrashBounty Agents", lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, object]:
    return {"status": "ok", "telegram_bot": telegram_app is not None}


@app.post("/internal/notify")
async def internal_notify(payload: NotifyPayload, request: Request) -> dict[str, bool]:
    if not settings.trashbounty_internal_secret or request.headers.get("X-Internal-Secret") != settings.trashbounty_internal_secret:
        raise HTTPException(status_code=401, detail="akses internal tidak valid")
    if telegram_app is None:
        raise HTTPException(status_code=503, detail="telegram bot belum aktif")

    await telegram_app.bot.send_message(chat_id=payload.telegram_chat_id, text=payload.message)
    return {"success": True}


@app.post("/internal/agency-escalations")
async def internal_agency_escalation(payload: AgencyEscalationPayload, request: Request) -> dict[str, bool]:
    if not settings.trashbounty_internal_secret or request.headers.get("X-Internal-Secret") != settings.trashbounty_internal_secret:
        raise HTTPException(status_code=401, detail="akses internal tidak valid")

    try:
        await agency_mailer.send_agency_escalation(payload)
    except Exception as exc:  # pragma: no cover - translated into API error detail
        raise HTTPException(status_code=500, detail=str(exc)) from exc

    return {"success": True}


@app.post("/generate-report")
async def generate_report_endpoint(request: Request) -> Response:
    if not settings.trashbounty_internal_secret or request.headers.get("X-Internal-Secret") != settings.trashbounty_internal_secret:
        return JSONResponse({"error": "Unauthorized"}, status_code=401)

    body = await request.json()
    period = str(body.get("period", "monthly")).strip().lower()
    if period not in {"weekly", "monthly", "alltime"}:
        return JSONResponse({"error": "Invalid period"}, status_code=400)

    docx_bytes = await generate_full_report(period)
    filename = f"laporan-trashbounty-{period}.docx"
    return Response(
        content=docx_bytes,
        media_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=settings.port)