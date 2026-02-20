#!/usr/bin/env python3
"""
Analyze 65 journey JSON files for visual consistency and content quality issues.
Scans for inconsistencies with card display from visual appeal standpoint.
"""

import json
import os
from pathlib import Path
from dataclasses import dataclass
from typing import List, Dict, Set, Tuple
from collections import defaultdict
import re

@dataclass
class ContentIssue:
    journey: str
    activity_id: str
    card_index: int
    card_type: str
    severity: str  # 'warning', 'error', 'info'
    issue: str
    details: str = ""

class JourneyAnalyzer:
    def __init__(self):
        self.issues: List[ContentIssue] = []
        self.journey_stats = defaultdict(int)
        self.card_type_counts = defaultdict(int)
        self.text_length_stats = defaultdict(list)
        
    def analyze_all_journeys(self, base_path: str) -> Dict:
        """Analyze all journey JSON files in the directory."""
        journey_dir = Path(base_path) / "assets/config/journeys"
        
        if not journey_dir.exists():
            print(f"✗ Journey directory not found: {journey_dir}")
            return {}
        
        journey_files = list(journey_dir.glob("**/**.json"))
        print(f"Found {len(journey_files)} journey JSON files\n")
        
        results = {
            'total_files': len(journey_files),
            'journey_types': defaultdict(dict),
            'total_cards': 0,
            'total_activities': 0,
        }
        
        for filepath in sorted(journey_files):
            self._analyze_file(filepath, results)
        
        return results
    
    def _analyze_file(self, filepath: Path, results: Dict) -> None:
        """Analyze a single journey JSON file."""
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            # Determine journey type
            journey_type = self._get_journey_type(filepath)
            journey_title = data.get('title', 'Unknown')
            journey_id = data.get('journeyId', 'unknown')
            
            if 'activities' in data:
                for activity in data['activities']:
                    self._analyze_activity(
                        journey_id,
                        journey_title,
                        activity, 
                        journey_type, 
                        results
                    )
        
        except json.JSONDecodeError as e:
            issue = ContentIssue(
                journey=str(filepath.name),
                activity_id="N/A",
                card_index=-1,
                card_type="N/A",
                severity="error",
                issue=f"Invalid JSON: {str(e)}"
            )
            self.issues.append(issue)
        except Exception as e:
            issue = ContentIssue(
                journey=str(filepath.name),
                activity_id="N/A",
                card_index=-1,
                card_type="N/A",
                severity="error",
                issue=f"Read error: {str(e)}"
            )
            self.issues.append(issue)
    
    def _get_journey_type(self, filepath: Path) -> str:
        """Extract journey type from filepath."""
        if 'singles journeys' in str(filepath):
            return 'singles'
        elif 'married journeys' in str(filepath):
            return 'married'
        elif 'divorced journeys' in str(filepath):
            return 'divorced'
        elif 'widowed journeys' in str(filepath):
            return 'widowed'
        return 'unknown'
    
    def _analyze_activity(self, journey_id: str, journey_title: str, activity: Dict, journey_type: str, results: Dict) -> None:
        """Analyze a single activity within a journey."""
        activity_id = activity.get('id', 'unknown')
        activity_num = activity.get('activityNumber', '?')
        cards = activity.get('cards', [])
        
        if journey_type not in results['journey_types']:
            results['journey_types'][journey_type] = {
                'journeys': set(),
                'total_activities': 0,
                'total_cards': 0,
                'card_types': defaultdict(int),
                'issues': []
            }
        
        results['journey_types'][journey_type]['total_activities'] += 1
        results['journey_types'][journey_type]['journeys'].add(journey_id)
        results['total_activities'] += 1
        
        for card_index, card in enumerate(cards):
            self._analyze_card(
                journey_id,
                activity_id,
                card_index, 
                card, 
                journey_type,
                results
            )
    
    def _analyze_card(self, journey_id: str, activity_id: str, card_index: int, card: Dict, journey_type: str, results: Dict) -> None:
        """Analyze visual consistency of a single card."""
        card_type = card.get('cardType') or 'unknown'
        title = card.get('title', '').strip()
        text = card.get('text', '').strip()
        icon = card.get('icon', '')
        prompts = card.get('prompts', [])
        reflection = card.get('reflection', '')
        responseType = card.get('responseType', '')
        
        # Track card type counts
        self.card_type_counts[str(card_type)] += 1
        results['journey_types'][journey_type]['card_types'][str(card_type)] += 1
        results['journey_types'][journey_type]['total_cards'] += 1
        results['total_cards'] += 1
        
        # === VISUAL CONSISTENCY CHECKS ===
        
        # 1. Missing title
        if not title:
            issue = ContentIssue(
                journey=journey_id,
                activity_id=activity_id,
                card_index=card_index,
                card_type=str(card_type),
                severity="error",
                issue="Missing card title",
                details=f"Card at index {card_index} has no title - breaks visual hierarchy"
            )
            self.issues.append(issue)
        
        # 2. Title too long/too short
        if title and (len(title) > 120):
            issue = ContentIssue(
                journey=journey_id,
                activity_id=activity_id,
                card_index=card_index,
                card_type=str(card_type),
                severity="warning",
                issue="Title unusually long",
                details=f"Title length: {len(title)} chars (typical: 15-70 chars) - may wrap awkwardly"
            )
            self.issues.append(issue)
        
        if title and len(title) < 3:
            issue = ContentIssue(
                journey=journey_id,
                activity_id=activity_id,
                card_index=card_index,
                card_type=str(card_type),
                severity="warning",
                issue="Title too short",
                details=f"Title: '{title}' - should be more descriptive"
            )
            self.issues.append(issue)
        
        # 3. Content consistency checks by card type
        if card_type == 'teaching':
            if not text:
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="error",
                    issue="Teaching card missing text",
                    details="Teaching cards should have meaningful text content"
                )
                self.issues.append(issue)
            else:
                # Check text length
                if len(text) < 20:
                    issue = ContentIssue(
                        journey=journey_id,
                        activity_id=activity_id,
                        card_index=card_index,
                        card_type=str(card_type),
                        severity="warning",
                        issue="Teaching text too short",
                        details=f"Text: {len(text)} chars. Consider expanding for better visual appeal."
                    )
                    self.issues.append(issue)
                
                if len(text) > 2500:
                    issue = ContentIssue(
                        journey=journey_id,
                        activity_id=activity_id,
                        card_index=card_index,
                        card_type=str(card_type),
                        severity="warning",
                        issue="Teaching text very long",
                        details=f"Text: {len(text)} chars. May overwhelm on mobile."
                    )
                    self.issues.append(issue)
                
                # Check for poor paragraph structure (excessive newlines - may indicate formatting issues)
                newline_count = text.count('\n')
                if newline_count > 20:
                    issue = ContentIssue(
                        journey=journey_id,
                        activity_id=activity_id,
                        card_index=card_index,
                        card_type=str(card_type),
                        severity="warning",
                        issue="Excessive line breaks in text",
                        details=f"Text has {newline_count} line breaks. May create visual fragmentation."
                    )
                    self.issues.append(issue)
        
        # 4. Question card validation
        if card_type == 'question':
            if not prompts or len(prompts) == 0:
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="error",
                    issue="Question card missing prompts",
                    details="Question cards should have at least one prompt"
                )
                self.issues.append(issue)
            else:
                # Check each prompt
                for prompt_idx, prompt in enumerate(prompts):
                    if not isinstance(prompt, dict):
                        issue = ContentIssue(
                            journey=journey_id,
                            activity_id=activity_id,
                            card_index=card_index,
                            card_type=str(card_type),
                            severity="error",
                            issue="Invalid prompt format",
                            details=f"Prompt {prompt_idx} is not a dict: {type(prompt)}"
                        )
                        self.issues.append(issue)
                    else:
                        prompt_text = prompt.get('prompt', '').strip() if isinstance(prompt, dict) else ''
                        if not prompt_text:
                            issue = ContentIssue(
                                journey=journey_id,
                                activity_id=activity_id,
                                card_index=card_index,
                                card_type=str(card_type),
                                severity="warning",
                                issue="Empty prompt text",
                                details=f"Prompt {prompt_idx} is empty"
                            )
                            self.issues.append(issue)
                        elif len(prompt_text) > 200:
                            issue = ContentIssue(
                                journey=journey_id,
                                activity_id=activity_id,
                                card_index=card_index,
                                card_type=str(card_type),
                                severity="warning",
                                issue="Prompt text too long",
                                details=f"Prompt {prompt_idx}: {len(prompt_text)} chars - may wrap awkwardly"
                            )
                            self.issues.append(issue)
        
        # 5. Reflection card validation
        if card_type == 'reflection':
            if not reflection:
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="warning",
                    issue="Reflection card missing reflection text",
                    details="Reflection cards should have reflection prompt text"
                )
                self.issues.append(issue)
            else:
                if len(reflection) < 10:
                    issue = ContentIssue(
                        journey=journey_id,
                        activity_id=activity_id,
                        card_index=card_index,
                        card_type=str(card_type),
                        severity="warning",
                        issue="Reflection prompt too short",
                        details=f"Reflection: {len(reflection)} chars. Should be more substantial."
                    )
                    self.issues.append(issue)
                elif len(reflection) > 300:
                    issue = ContentIssue(
                        journey=journey_id,
                        activity_id=activity_id,
                        card_index=card_index,
                        card_type=str(card_type),
                        severity="warning",
                        issue="Reflection prompt very long",
                        details=f"Reflection: {len(reflection)} chars. May be overwhelming."
                    )
                    self.issues.append(issue)
        
        # 6. Action card validation
        if card_type == 'action':
            if not text:
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="error",
                    issue="Action card missing text",
                    details="Action cards should describe the action to take"
                )
                self.issues.append(issue)
        
        # 7. Icon consistency - log if missing (useful for visual appeal)
        if card_type in ['teaching', 'action', 'reflection'] and not icon:
            issue = ContentIssue(
                journey=journey_id,
                activity_id=activity_id,
                card_index=card_index,
                card_type=str(card_type),
                severity="info",
                issue="Missing icon for card",
                details=f"Card has no icon - reduces visual appeal and consistency"
            )
            self.issues.append(issue)
        
        # 8. Text formatting issues
        if text:
            # Check for excessive special characters (indicates potential formatting issues)
            special_char_count = len(re.findall(r'[*_#\[\]{}()!@$%^&\-=+\\|;<>?,./`~]', text))
            if special_char_count > len(text) * 0.2:  # More than 20% special chars
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="info",
                    issue="High special character density",
                    details=f"Text has {special_char_count} special chars ({special_char_count/len(text)*100:.1f}%) - check readability"
                )
                self.issues.append(issue)
            
            # Check for unclosed markdown-like patterns
            if text.count('**') % 2 != 0:
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="warning",
                    issue="Unmatched markdown pattern (asterisks)",
                    details="Text has odd number of ** - likely unclosed bold"
                )
                self.issues.append(issue)
            
            if text.count('__') % 2 != 0:
                issue = ContentIssue(
                    journey=journey_id,
                    activity_id=activity_id,
                    card_index=card_index,
                    card_type=str(card_type),
                    severity="warning",
                    issue="Unmatched markdown pattern (underscores)",
                    details="Text has odd number of __ - likely unclosed italic"
                )
                self.issues.append(issue)

    def print_summary(self) -> None:
        """Print analysis summary."""
        print("\n" + "="*80)
        print("JOURNEY JSON VISUAL CONSISTENCY ANALYSIS REPORT")
        print("="*80)
        
        print(f"\n📊 OVERALL STATISTICS:")
        print(f"  • Total card types found: {len(self.card_type_counts)}")
        print(f"  • Total issues detected: {len(self.issues)}")
        
        print(f"\n📈 CARD TYPE DISTRIBUTION:")
        for card_type, count in sorted(self.card_type_counts.items(), key=lambda x: x[1], reverse=True):
            print(f"  • {card_type}: {count}")
        
        # Sort issues by severity
        errors = [i for i in self.issues if i.severity == 'error']
        warnings = [i for i in self.issues if i.severity == 'warning']
        infos = [i for i in self.issues if i.severity == 'info']
        
        print(f"\n🚨 ISSUE BREAKDOWN:")
        print(f"  • Errors: {len(errors)}")
        print(f"  • Warnings: {len(warnings)}")
        print(f"  • Infos: {len(infos)}")
        
        # Print issues by severity
        if errors:
            print(f"\n❌ CRITICAL ERRORS ({len(errors)}):")
            for issue in sorted(errors, key=lambda x: (x.journey, x.card_index))[:15]:
                print(f"\n  📄 {issue.journey} | Activity: {issue.activity_id} | Card {issue.card_index} ({issue.card_type})")
                print(f"     └─ {issue.issue}")
                if issue.details:
                    print(f"     └─ {issue.details}")
        
        if warnings:
            print(f"\n⚠️  WARNINGS ({len(warnings)}):")
            # Group by issue type
            warning_groups = defaultdict(list)
            for w in warnings:
                warning_groups[w.issue].append(w)
            
            for issue_type, group in sorted(warning_groups.items(), key=lambda x: len(x[1]), reverse=True)[:10]:
                print(f"\n  ⚠️  {issue_type} ({len(group)} occurrences)")
                for warning in group[:2]:
                    print(f"     • {warning.journey} | Activity: {warning.activity_id} | Card {warning.card_index}")
                if len(group) > 2:
                    print(f"     ... and {len(group) - 2} more")
        
        if infos:
            print(f"\n💡 INFO NOTES ({len(infos)}):")
            # Group by issue type
            info_groups = defaultdict(list)
            for i in infos:
                info_groups[i.issue].append(i)
            
            for issue_type, group in sorted(info_groups.items(), key=lambda x: len(x[1]), reverse=True)[:8]:
                print(f"  💡 {issue_type} ({len(group)} occurrences)")


def main():
    workspace_root = "/Users/aybaj/Documents/nexus_app_v2"
    
    analyzer = JourneyAnalyzer()
    results = analyzer.analyze_all_journeys(workspace_root)
    
    analyzer.print_summary()
    
    # Print files processed by type
    print(f"\n📁 JOURNEY TYPES ANALYSIS:")
    total_journeys = set()
    for journey_type, data in sorted(results['journey_types'].items()):
        journeys = data['journeys']
        total_journeys.update(journeys)
        print(f"\n  {journey_type.upper()}: {len(journeys)} journeys")
        print(f"    • Total activities: {data['total_activities']}")
        print(f"    • Total cards: {data['total_cards']}")
        print(f"    • Card type breakdown: {dict(data['card_types'])}")
    
    print(f"\n\n📊 GRAND TOTALS:")
    print(f"  • Total journeys analyzed: {len(total_journeys)}")
    print(f"  • Total activities: {results['total_activities']}")
    print(f"  • Total cards: {results['total_cards']}")
    
    # Generate detailed report
    print(f"\n" + "="*80)
    print("VISUAL CONSISTENCY ISSUES - DETAILED BREAKDOWN")
    print("="*80)
    
    if analyzer.issues:
        print(f"\nTotal issues to review: {len(analyzer.issues)}\n")
        
        # Export to CSV for easy filtering
        csv_output = "/Users/aybaj/Documents/nexus_app_v2/journey_consistency_report.csv"
        with open(csv_output, 'w', encoding='utf-8') as f:
            f.write("Journey,Activity,Card Index,Card Type,Severity,Issue,Details\n")
            for issue in sorted(analyzer.issues, key=lambda x: (x.severity, x.journey)):
                details = issue.details.replace('\n', ' | ').replace(',', ';')
                f.write(f'"{issue.journey}","{issue.activity_id}",{issue.card_index},"{issue.card_type}","{issue.severity}","{issue.issue}","{details}"\n')
        
        print(f"✅ Detailed report exported to: {csv_output}")
    else:
        print("\n✅ No consistency issues found!")


if __name__ == '__main__':
    main()
