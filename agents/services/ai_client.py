from __future__ import annotations

import os

from openai import AsyncOpenAI


MODEL = "gpt-5.4-mini"


def _get_client() -> AsyncOpenAI:
	api_key = os.getenv("OPENAI_API_KEY")
	if not api_key:
		raise RuntimeError("OPENAI_API_KEY belum dikonfigurasi")
	return AsyncOpenAI(api_key=api_key)


async def generate_narrative(stats: dict, period: str) -> str:
	"""Generate an Indonesian executive summary for cleanup stats using GPT 5.4 mini."""
	waste_type_names = [
		str(item.get("waste_type", "")).strip()
		for item in stats.get("waste_types", [])[:3]
		if str(item.get("waste_type", "")).strip()
	]
	top_waste_types = ", ".join(waste_type_names) if waste_type_names else "belum ada kategori dominan"

	prompt = f"""Kamu adalah Lumi, analis lingkungan untuk TrashBounty.
Bersikaplah profesional, hangat, dan jelas dalam menyusun ringkasan.
Buat ringkasan eksekutif profesional dalam Bahasa Indonesia, terdiri dari 2 sampai 3 paragraf.

Data periode {period}:
- Total bounty selesai: {stats.get('total_completed', 0)}
- Estimasi total sampah dibersihkan: {float(stats.get('total_weight_kg', 0)):.1f} kg
- Total poin didistribusikan: {stats.get('total_points_awarded', 0)}
- Total reward didistribusikan: Rp {float(stats.get('total_reward_idr', 0)):,.0f}
- Jenis sampah dominan: {top_waste_types}

Fokuskan pada:
1. Dampak lingkungan yang paling terasa.
2. Kontribusi komunitas dan insentif yang berhasil berjalan.
3. Ajakan singkat untuk mempertahankan momentum.

Jangan gunakan markdown, bullet list, atau judul. Tulis langsung sebagai paragraf naratif yang rapi."""

	response = await _create_completion(prompt)
	return (response.choices[0].message.content or "").strip()


async def _create_completion(prompt: str):
	client = _get_client()
	response = await client.chat.completions.create(
		model=MODEL,
		messages=[{"role": "user", "content": prompt}],
		temperature=0.7,
		max_completion_tokens=600,
	)
	return response