#!/usr/bin/env python3
"""Spot check a few cards visually."""
import json

checks = [
    ("assets/config/journeys/singles journeys/singles_journey_03_healing_past_wounds.json", "c2", "Healthy love"),
    ("assets/config/journeys/singles journeys/singles_journey_07_secure_confidence.json", "c1", "confidence"),
    ("assets/config/journeys/married journeys/married_journey_01_communication_conflict.json", "c2", "communication"),
]

for fpath, target_cid, label in checks:
    data = json.load(open(fpath))
    cards = []
    for act in data.get("activities",[]): cards.extend(act.get("cards",[]))
    for card in cards:
        if card.get("cardId") == target_cid:
            text = card.get("text","")
            lines = text.split("\n")
            for i, line in enumerate(lines):
                if line.strip().startswith("• "):
                    start = max(0, i-2)
                    end = min(len(lines), i+6)
                    fname = fpath.split("/")[-1]
                    print(f"=== {fname} {target_cid} ({label}) ===")
                    for j in range(start, end):
                        print(f"  {lines[j]}")
                    print()
                    break
            break
