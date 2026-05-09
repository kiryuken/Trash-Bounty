from __future__ import annotations

from datetime import datetime
from io import BytesIO

from telegram import Update
from telegram.constants import ChatAction
from telegram.ext import Application, CommandHandler, ContextTypes, MessageHandler, filters

from services.backend_client import BackendClient
from services.report_generator import generate_full_report


def register_handlers(application: Application, backend_client: BackendClient) -> None:
    application.add_handler(CommandHandler("start", _start_command))
    application.add_handler(CommandHandler("cancel", _cancel_command))
    application.add_handler(CommandHandler("bounties", _bounties_command_factory(backend_client)))
    application.add_handler(CommandHandler("generate", _generate_report_command))
    application.add_handler(CommandHandler("link", _link_command_factory(backend_client)))
    application.add_handler(CommandHandler("unlink", _unlink_command_factory(backend_client)))
    application.add_handler(CommandHandler("report", _report_command))
    application.add_handler(CommandHandler("reports", _reports_command_factory(backend_client)))
    application.add_handler(CommandHandler("reportstatus", _report_status_command_factory(backend_client)))
    application.add_handler(CommandHandler("status", _status_command_factory(backend_client)))
    application.add_handler(CommandHandler("nearby", _nearby_command))
    application.add_handler(MessageHandler(filters.PHOTO, _report_photo_handler))
    application.add_handler(MessageHandler(filters.LOCATION, _location_handler_factory(backend_client)))
    application.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, _support_handler_factory(backend_client)))


async def _start_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message is None:
        return
    await update.message.reply_text(
        "Halo. Bot TrashBounty siap dipakai.\n\n"
        "Perintah utama:\n"
        "/link <token> untuk menghubungkan akun\n"
        "/unlink untuk memutuskan akun Telegram\n"
        "/bounties untuk melihat bounty yang kamu buat atau ambil\n"
        "/report untuk kirim laporan sampah dari Telegram\n"
        "/reports untuk melihat laporan terbaru\n"
        "/reportstatus <id> untuk cek status laporan\n"
        "/status untuk melihat ringkasan akun\n"
        "/nearby untuk meminta bounty terdekat\n"
        "/generate [weekly|monthly|alltime] untuk membuat laporan dampak\n\n"
        "Kamu juga bisa langsung kirim pertanyaan tentang TrashBounty."
    )


async def _cancel_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message is None:
        return
    _clear_report_state(context)
    context.user_data["awaiting_location"] = False
    await update.message.reply_text("Flow aktif dibatalkan.")


async def _report_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message is None:
        return
    context.user_data["awaiting_location"] = False
    context.user_data["report_draft"] = {"stage": "awaiting_photo"}
    await update.message.reply_text(
        "Kirim foto lokasi sampah yang ingin dilaporkan. Setelah itu saya akan minta lokasi kamu.\n\n"
        "Gunakan /cancel kalau mau membatalkan."
    )


async def _generate_report_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message is None:
        return

    period = context.args[0].strip().lower() if context.args else "monthly"
    if period not in {"weekly", "monthly", "alltime"}:
        await update.message.reply_text("❌ Periode tidak valid. Gunakan: weekly, monthly, atau alltime")
        return

    period_labels = {
        "weekly": "Mingguan",
        "monthly": "Bulanan",
        "alltime": "Semua Waktu",
    }
    status_message = await update.message.reply_text("⏳ Mengumpulkan data statistik...")

    try:
        await status_message.edit_text("🤖 Lumi sedang menganalisis data (GPT 5.4 mini)...")
        docx_bytes = await generate_full_report(period)
        await status_message.edit_text("📄 Membuat dokumen laporan...")

        filename = f"laporan-trashbounty-{period}-{datetime.now().strftime('%Y%m%d')}.docx"
        buffer = BytesIO(docx_bytes)
        buffer.name = filename
        buffer.seek(0)

        await context.bot.send_document(
            chat_id=update.effective_chat.id,
            document=buffer,
            caption=(
                "✅ Laporan Dampak Lingkungan TrashBounty Lumi\n"
                f"Periode: {period_labels[period]}"
            ),
        )
        await status_message.delete()
    except Exception as exc:
        await status_message.edit_text(f"❌ Gagal membuat laporan: {exc}")


def _link_command_factory(backend_client: BackendClient):
    async def _link_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None:
            return
        if not context.args:
            await update.message.reply_text("Gunakan format: /link <token>")
            return

        token = context.args[0].strip()
        chat_id = str(update.effective_chat.id)
        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            await backend_client.link_account(token, chat_id)
            await update.message.reply_text("Akun Telegram berhasil terhubung ke TrashBounty.")
        except RuntimeError as exc:
            await update.message.reply_text(f"Gagal menghubungkan akun: {exc}")

    return _link_command


def _unlink_command_factory(backend_client: BackendClient):
    async def _unlink_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None:
            return

        _clear_report_state(context)
        context.user_data["awaiting_location"] = False

        chat_id = str(update.effective_chat.id)
        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            await backend_client.unlink_account(chat_id)
            await update.message.reply_text("Akun Telegram berhasil diputuskan dari TrashBounty.")
        except RuntimeError as exc:
            await update.message.reply_text(f"Gagal memutuskan akun Telegram: {exc}")

    return _unlink_command


def _status_command_factory(backend_client: BackendClient):
    async def _status_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None:
            return

        chat_id = str(update.effective_chat.id)
        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            data = await backend_client.get_status(chat_id)
        except RuntimeError as exc:
            await update.message.reply_text(f"Status belum bisa diambil: {exc}")
            return

        user = data.get("user", {})
        stats = data.get("stats", {})
        await update.message.reply_text(
            "Status TrashBounty\n"
            f"Nama: {user.get('name', '-')}\n"
            f"Role: {user.get('role', '-')}\n"
            f"Poin: {stats.get('total_points', 0)}\n"
            f"Dompet: Rp {int(float(stats.get('wallet_balance', 0))):,}\n"
            f"Rank: {stats.get('current_rank') or '-'}\n"
            f"Total laporan: {stats.get('total_reports', 0)}\n"
            f"Bounty terbuka: {stats.get('pending_bounties', 0)}"
        )

    return _status_command


def _bounties_command_factory(backend_client: BackendClient):
    async def _bounties_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None:
            return

        chat_id = str(update.effective_chat.id)
        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            data = await backend_client.get_bounties(chat_id, limit=5)
        except RuntimeError as exc:
            await update.message.reply_text(f"Daftar bounty belum bisa diambil: {exc}")
            return

        created = data.get("created") or []
        assigned = data.get("assigned") or []
        if not created and not assigned:
            await update.message.reply_text("Belum ada bounty yang terkait dengan akun ini.")
            return

        sections: list[str] = []
        if created:
            lines = ["Bounty dari laporan kamu:"]
            for index, item in enumerate(created, start=1):
                lines.append(
                    f"{index}. {item.get('location', '-')}\n"
                    f"   Status: {item.get('status', '-')}\n"
                    f"   Reward: Rp {int(float(item.get('reward', 0))):,}"
                )
            sections.append("\n\n".join(lines))

        if assigned:
            lines = ["Bounty yang kamu ambil:"]
            for index, item in enumerate(assigned, start=1):
                lines.append(
                    f"{index}. {item.get('location', '-')}\n"
                    f"   Status: {item.get('status', '-')}\n"
                    f"   Reward: Rp {int(float(item.get('reward', 0))):,}"
                )
            sections.append("\n\n".join(lines))

        await update.message.reply_text("\n\n".join(sections))

    return _bounties_command


def _reports_command_factory(backend_client: BackendClient):
    async def _reports_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None:
            return

        chat_id = str(update.effective_chat.id)
        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            reports = await backend_client.list_reports(chat_id, limit=5)
        except RuntimeError as exc:
            await update.message.reply_text(f"Daftar laporan belum bisa diambil: {exc}")
            return

        if not reports:
            await update.message.reply_text("Belum ada laporan yang terhubung ke akun ini.")
            return

        lines = ["5 laporan terbaru:"]
        for index, item in enumerate(reports, start=1):
            points = item.get("points_earned")
            points_text = f" | Poin: {points}" if points is not None else ""
            lines.append(
                f"{index}. {item.get('id', '-')}\n"
                f"   Lokasi: {item.get('location_text', '-')}\n"
                f"   Status: {item.get('status', '-')}"
                f"{points_text}"
            )

        lines.append("Gunakan /reportstatus <id> untuk detail status laporan tertentu.")
        await update.message.reply_text("\n\n".join(lines))

    return _reports_command


def _report_status_command_factory(backend_client: BackendClient):
    async def _report_status_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None:
            return
        if not context.args:
            await update.message.reply_text("Gunakan format: /reportstatus <report_id>")
            return

        report_id = context.args[0].strip()
        chat_id = str(update.effective_chat.id)

        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            data = await backend_client.get_report_status(chat_id, report_id)
        except RuntimeError as exc:
            await update.message.reply_text(f"Status laporan belum bisa diambil: {exc}")
            return

        points = data.get("points_earned")
        reward = data.get("reward_idr")
        reasoning = data.get("ai_reasoning") or "-"
        reward_text = f"Rp {int(float(reward)):,}" if reward is not None else "-"
        await update.message.reply_text(
            "Status laporan\n"
            f"ID: {data.get('id', '-')}\n"
            f"Lokasi: {data.get('location_text', '-')}\n"
            f"Status: {data.get('status', '-')} ({data.get('progress', 0)}%)\n"
            f"Jenis sampah: {data.get('waste_type') or '-'}\n"
            f"Severity: {data.get('severity') or '-'}\n"
            f"Poin: {points if points is not None else '-'}\n"
            f"Reward: {reward_text}\n"
            f"Catatan Lumi: {reasoning}"
        )

    return _report_status_command


async def _nearby_command(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message is None:
        return
    draft = context.user_data.get("report_draft")
    if isinstance(draft, dict):
        await update.message.reply_text("Selesaikan atau batalkan flow /report terlebih dahulu dengan /cancel.")
        return
    context.user_data["awaiting_location"] = True
    await update.message.reply_text("Kirim lokasi kamu sekarang agar saya carikan bounty terdekat.")


async def _report_photo_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
    if update.message is None or not update.message.photo:
        return

    draft = context.user_data.get("report_draft")
    if not isinstance(draft, dict) or draft.get("stage") != "awaiting_photo":
        return

    photo = update.message.photo[-1]
    caption = (update.message.caption or "").strip()
    context.user_data["report_draft"] = {
        "stage": "awaiting_location",
        "file_id": photo.file_id,
        "location_text": caption,
    }
    await update.message.reply_text(
        "Foto sudah saya terima. Sekarang kirim lokasi Telegram kamu untuk melengkapi laporan ini."
    )


def _location_handler_factory(backend_client: BackendClient):
    async def _location_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None or update.message.location is None:
            return

        draft = context.user_data.get("report_draft")
        if isinstance(draft, dict) and draft.get("stage") == "awaiting_location":
            await _submit_report_from_location(update, context, backend_client, draft)
            return

        if context.user_data.get("awaiting_location") is not True:
            return

        context.user_data["awaiting_location"] = False
        chat_id = str(update.effective_chat.id)
        location = update.message.location

        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            recommendations = await backend_client.get_recommended(chat_id, location.latitude, location.longitude)
        except RuntimeError as exc:
            await update.message.reply_text(f"Gagal mengambil rekomendasi bounty: {exc}")
            return

        if not recommendations:
            await update.message.reply_text("Belum ada bounty yang cocok di sekitar lokasi kamu.")
            return

        lines = ["Rekomendasi bounty terdekat:"]
        for index, item in enumerate(recommendations, start=1):
            reward = int(float(item.get("reward", 0)))
            lines.append(
                f"{index}. {item.get('location', '-')}\n"
                f"   Reward: Rp {reward:,}\n"
                f"   Jarak: {item.get('distance', '-')}\n"
                f"   Lumi: {item.get('reasoning', 'Rekomendasi berdasarkan lokasi dan reward')}"
            )
        await update.message.reply_text("\n\n".join(lines))

    return _location_handler


def _support_handler_factory(backend_client: BackendClient):
    async def _support_handler(update: Update, context: ContextTypes.DEFAULT_TYPE) -> None:
        if update.message is None or not update.message.text:
            return

        draft = context.user_data.get("report_draft")
        if isinstance(draft, dict):
            stage = draft.get("stage")
            if stage == "awaiting_photo":
                await update.message.reply_text("Saya sedang menunggu foto untuk laporan. Kirim foto atau gunakan /cancel.")
                return
            if stage == "awaiting_location":
                await update.message.reply_text("Saya sedang menunggu lokasi Telegram untuk laporan. Kirim lokasi atau gunakan /cancel.")
                return

        history: list[dict[str, str]] = context.user_data.setdefault("support_history", [])
        history.append({"role": "user", "content": update.message.text.strip()})
        history = history[-8:]
        context.user_data["support_history"] = history

        try:
            await update.message.chat.send_action(action=ChatAction.TYPING)
            reply = await backend_client.support_chat(history)
        except RuntimeError as exc:
            await update.message.reply_text(f"Lumi sedang tidak tersedia: {exc}")
            return

        history.append({"role": "assistant", "content": reply})
        context.user_data["support_history"] = history[-8:]
        await update.message.reply_text(reply)

    return _support_handler


async def _submit_report_from_location(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
    backend_client: BackendClient,
    draft: dict[str, str],
) -> None:
    if update.message is None or update.message.location is None:
        return

    file_id = str(draft.get("file_id", "")).strip()
    if not file_id:
        _clear_report_state(context)
        await update.message.reply_text("Foto laporan tidak ditemukan. Mulai lagi dengan /report.")
        return

    location = update.message.location
    location_text = str(draft.get("location_text", "")).strip()
    if not location_text:
        location_text = f"Lokasi Telegram ({location.latitude:.5f}, {location.longitude:.5f})"

    try:
        await update.message.chat.send_action(action=ChatAction.TYPING)
        telegram_file = await context.bot.get_file(file_id)
        buffer = BytesIO()
        await telegram_file.download_to_memory(out=buffer)
        data = await backend_client.create_report(
            telegram_chat_id=str(update.effective_chat.id),
            image_bytes=buffer.getvalue(),
            location_text=location_text,
            lat=location.latitude,
            lon=location.longitude,
        )
    except RuntimeError as exc:
        await update.message.reply_text(f"Laporan gagal dikirim: {exc}")
        return
    except Exception:
        await update.message.reply_text("Gagal mengambil foto dari Telegram. Coba kirim ulang dengan /report.")
        return

    _clear_report_state(context)
    await update.message.reply_text(
        "Laporan berhasil dikirim.\n"
        f"ID laporan: {data.get('report_id', '-')}\n"
        f"Status: {data.get('status', 'ai_analyzing')}"
    )


def _clear_report_state(context: ContextTypes.DEFAULT_TYPE) -> None:
    context.user_data.pop("report_draft", None)