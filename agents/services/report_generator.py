from __future__ import annotations

import os

import httpx
from dotenv import load_dotenv

from services.ai_client import generate_narrative
from services.docx_builder import build_report


DEFAULT_TRASHBOUNTY_API_URL = "http://localhost:8080"

load_dotenv(".env.local")
load_dotenv(".env")


def _backend_url() -> str:
	return os.getenv("TRASHBOUNTY_API_URL", DEFAULT_TRASHBOUNTY_API_URL).rstrip("/")


async def generate_full_report(period: str = "monthly") -> bytes:
	"""Gather cleanup stats, summarize them with GPT 5.4 mini, and return a DOCX file."""
	backend_url = _backend_url()
	async with httpx.AsyncClient(timeout=30.0) as client:
		response = await client.get(
			f"{backend_url}/v1/stats/cleanup",
			params={"period": period},
		)
		response.raise_for_status()
		payload = response.json()
		stats = payload.get("data", payload)

	narrative = await generate_narrative(stats, period)
	return build_report(stats, narrative, period)