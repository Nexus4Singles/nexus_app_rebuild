#!/usr/bin/env python3
import json
import re

# Read singles assessment to extract actual dimension IDs and names
with open('assets/config/assessments/singles_readiness_v1.json') as f:
    singles_data = json.load(f)

dimensions = []
for dim in singles_data['dimensions']:
    dimensions.append({
        'id': dim['id'],
        'name': dim['name'],
        'recommendedJourney': dim.get('insights', {}).get('recommendedJourney', '')
    })

print("SINGULAR READINESS ASSESSMENT DIMENSIONS:")
print("=" * 80)
for i, d in enumerate(dimensions, 1):
    print(f"{i:2d}. {d['id']:40s} - {d['name']}")
    if d['recommendedJourney']:
        print(f"     → Built-in journey: {d['recommendedJourney']}")

# Mapping of hardcoded recommendations from the assessment itself
hardcoded_recommendations = {
    'attachment_security': 'building_emotional_security_singles',
    'communication_style': None,  # Need to map
    'commitment_to_growth': None,
    'conflict_posture': 'mastering_conflict_skills_singles',
    'conflict_resolution_pattern': 'conflict_recovery_roadmap_singles',
    'decision_making_alignment': 'clarifying_shared_values_singles',
    'emotional_readiness': None,
    'emotional_regulation': 'emotional_mastery_singles',
    'emotional_intelligence': None,
    'family_background_learned_patterns': 'healing_family_patterns_singles',
    'hard_season_coping': 'building_resilience_singles',
    'identity_and_worth': None,
    'relational_boundaries': None,
    'relational_health': None,
    'relational_readiness': None,
    'relational_self_awareness': 'deepening_self_awareness_singles',
    'relational_expectations': None,
    'sacrifice_readiness': 'cultivating_sacrificial_love_singles',
    'spiritual_consistency': 'strengthening_spiritual_foundation_singles',
    'spiritual_leadership_understanding': 'building_spiritual_leadership_singles',
    'trigger_handling': 'understanding_your_triggers_singles',
    'unresolved_wounds': 'healing_deep_wounds_singles'
}

# Map dimensions to available journeys
dimension_to_journeys = {}

# Primary mappings (using hardcoded recommendations + strategic additions)
dimension_to_journeys = {
    'attachment_security': [
        'singles_journey_01_identity_self_worth',
        'singles_journey_05_emotional_readiness',
        'singles_journey_07_secure_confidence',
        'singles_journey_20_fear_commitment'
    ],
    'communication_style': [
        'singles_journey_10_communicate_better',
        'singles_journey_11_healthy_boundaries',
        'singles_journey_14_compatibility',
        'singles_journey_06_emotional_intelligence'
    ],
    'commitment_to_growth': [
        'singles_journey_02_cultural_lies',
        'singles_journey_12_financial_readiness',
        'singles_journey_15_dating_purpose',
        'singles_journey_17_faith_alignment'
    ],
    'conflict_posture': [
        'singles_journey_08_toxic_triggers',
        'singles_journey_10_communicate_better',
        'singles_journey_11_healthy_boundaries',
        'singles_journey_04_family_patterns'
    ],
    'conflict_resolution_pattern': [
        'singles_journey_04_family_patterns',
        'singles_journey_10_communicate_better',
        'singles_journey_11_healthy_boundaries',
        'singles_journey_06_emotional_intelligence'
    ],
    'decision_making_alignment': [
        'singles_journey_02_cultural_lies',
        'singles_journey_14_compatibility',
        'singles_journey_17_faith_alignment',
        'singles_journey_19_choosing_spouse',
        'singles_journey_15_dating_purpose'
    ],
    'emotional_readiness': [
        'singles_journey_05_emotional_readiness',
        'singles_journey_06_emotional_intelligence',
        'singles_journey_01_identity_self_worth',
        'singles_journey_07_secure_confidence',
        'singles_journey_03_healing_past_wounds'
    ],
    'emotional_regulation': [
        'singles_journey_05_emotional_readiness',
        'singles_journey_06_emotional_intelligence',
        'singles_journey_04_family_patterns',
        'singles_journey_10_communicate_better',
        'singles_journey_03_healing_past_wounds'
    ],
    'emotional_intelligence': [
        'singles_journey_06_emotional_intelligence',
        'singles_journey_05_emotional_readiness',
        'singles_journey_10_communicate_better',
        'singles_journey_08_toxic_triggers'
    ],
    'family_background_learned_patterns': [
        'singles_journey_03_healing_past_wounds',
        'singles_journey_04_family_patterns',
        'singles_journey_07_secure_confidence',
        'singles_journey_14_compatibility'
    ],
    'hard_season_coping': [
        'singles_journey_04_family_patterns',
        'singles_journey_05_emotional_readiness',
        'singles_journey_06_emotional_intelligence',
        'singles_journey_17_faith_alignment',
        'singles_journey_03_healing_past_wounds'
    ],
    'identity_and_worth': [
        'singles_journey_01_identity_self_worth',
        'singles_journey_09_biblical_femininity',
        'singles_journey_09_biblical_masculinity',
        'singles_journey_07_secure_confidence'
    ],
    'relational_boundaries': [
        'singles_journey_11_healthy_boundaries',
        'singles_journey_18_purity',
        'singles_journey_08_toxic_triggers',
        'singles_journey_10_communicate_better',
        'singles_journey_05_emotional_readiness'
    ],
    'relational_health': [
        'singles_journey_14_compatibility',
        'singles_journey_16_sexual_chemistry',
        'singles_journey_10_communicate_better',
        'singles_journey_11_healthy_boundaries',
        'singles_journey_06_emotional_intelligence'
    ],
    'relational_readiness': [
        'singles_journey_01_identity_self_worth',
        'singles_journey_05_emotional_readiness',
        'singles_journey_14_compatibility',
        'singles_journey_20_fear_commitment',
        'singles_journey_19_choosing_spouse'
    ],
    'relational_self_awareness': [
        'singles_journey_01_identity_self_worth',
        'singles_journey_06_emotional_intelligence',
        'singles_journey_10_communicate_better',
        'singles_journey_05_emotional_readiness'
    ],
    'relational_expectations': [
        'singles_journey_02_cultural_lies',
        'singles_journey_14_compatibility',
        'singles_journey_19_choosing_spouse',
        'singles_journey_16_sexual_chemistry'
    ],
    'sacrifice_readiness': [
        'singles_journey_15_dating_purpose',
        'singles_journey_19_choosing_spouse',
        'singles_journey_17_faith_alignment',
        'singles_journey_14_compatibility'
    ],
    'spiritual_consistency': [
        'singles_journey_17_faith_alignment',
        'singles_journey_07_secure_confidence',
        'singles_journey_02_cultural_lies',
        'singles_journey_18_purity',
        'singles_journey_19_choosing_spouse'
    ],
    'spiritual_leadership_understanding': [
        'singles_journey_02_cultural_lies',
        'singles_journey_17_faith_alignment',
        'singles_journey_14_compatibility'
    ],
    'trigger_handling': [
        'singles_journey_03_healing_past_wounds',
        'singles_journey_04_family_patterns',
        'singles_journey_08_toxic_triggers',
        'singles_journey_06_emotional_intelligence',
        'singles_journey_05_emotional_readiness'
    ],
    'unresolved_wounds': [
        'singles_journey_03_healing_past_wounds',
        'singles_journey_04_family_patterns',
        'singles_journey_01_identity_self_worth',
        'singles_journey_07_secure_confidence',
        'singles_journey_17_faith_alignment'
    ]
}

# Journey titles (based on available journeys)
journey_titles = {
    'singles_journey_01_identity_self_worth': 'Identity & Self-Worth',
    'singles_journey_02_cultural_lies': 'Deconstructing Cultural Lies About Marriage',
    'singles_journey_03_healing_past_wounds': 'Healing Past Wounds',
    'singles_journey_04_family_patterns': 'Breaking Family Patterns',
    'singles_journey_05_emotional_readiness': 'Emotional Readiness',
    'singles_journey_06_emotional_intelligence': 'Building Emotional Intelligence',
    'singles_journey_07_secure_confidence': 'Growing in Secure Confidence',
    'singles_journey_08_toxic_triggers': 'Understanding Toxic Triggers',
    'singles_journey_09_biblical_femininity': 'Biblical Femininity',
    'singles_journey_09_biblical_masculinity': 'Biblical Masculinity',
    'singles_journey_10_communicate_better': 'Communication Skills',
    'singles_journey_11_healthy_boundaries': 'Healthy Boundaries',
    'singles_journey_12_financial_readiness': 'Financial Readiness',
    'singles_journey_13_red_flags': 'Recognizing Red Flags',
    'singles_journey_14_compatibility': 'Assessing Compatibility',
    'singles_journey_15_dating_purpose': 'Dating with Purpose',
    'singles_journey_16_sexual_chemistry': 'Sexual Chemistry & Physical Attraction',
    'singles_journey_17_faith_alignment': 'Faith Alignment',
    'singles_journey_18_purity': 'Purity & Boundaries',
    'singles_journey_19_choosing_spouse': 'Choosing a Spouse',
    'singles_journey_20_fear_commitment': 'Overcoming Fear of Commitment'
}

# Build rationales
rationales = {
    'attachment_security': {
        'singles_journey_01_identity_self_worth': 'Core foundation for feeling secure',
        'singles_journey_05_emotional_readiness': 'Emotional security is key to attachment',
        'singles_journey_07_secure_confidence': 'Directly addresses secure confidence',
        'singles_journey_20_fear_commitment': 'Fear blocks secure attachment'
    },
    'communication_style': {
        'singles_journey_10_communicate_better': 'Directly teaches communication skills',
        'singles_journey_11_healthy_boundaries': 'Communication within boundaries',
        'singles_journey_14_compatibility': 'Communication alignment with partner',
        'singles_journey_06_emotional_intelligence': 'EI includes communication awareness'
    },
    'commitment_to_growth': {
        'singles_journey_02_cultural_lies': 'Growth requires questioning false assumptions',
        'singles_journey_12_financial_readiness': 'Financial readiness is growth',
        'singles_journey_15_dating_purpose': 'Purpose-driven dating requires intentional growth',
        'singles_journey_17_faith_alignment': 'Spiritual growth centers on faith'
    },
    'conflict_posture': {
        'singles_journey_08_toxic_triggers': 'Recognizing toxic patterns that drive conflict',
        'singles_journey_10_communicate_better': 'Better communication = better conflict',
        'singles_journey_11_healthy_boundaries': 'Boundaries matter in conflict',
        'singles_journey_04_family_patterns': 'Family patterns shape conflict approaches'
    },
    'conflict_resolution_pattern': {
        'singles_journey_04_family_patterns': 'Family patterns repeat in conflict resolution',
        'singles_journey_10_communicate_better': 'Repair requires communication skills',
        'singles_journey_11_healthy_boundaries': 'Recovery needs clear boundaries',
        'singles_journey_06_emotional_intelligence': 'Repair requires emotional awareness'
    },
    'decision_making_alignment': {
        'singles_journey_02_cultural_lies': 'Must align on what marriage actually requires',
        'singles_journey_14_compatibility': 'Directly assesses values alignment',
        'singles_journey_17_faith_alignment': 'Faith values shape all decisions',
        'singles_journey_19_choosing_spouse': 'Decision-making is core to choosing',
        'singles_journey_15_dating_purpose': 'Purposeful dating aligns decisions'
    },
    'emotional_readiness': {
        'singles_journey_05_emotional_readiness': 'Directly addresses emotional readiness',
        'singles_journey_06_emotional_intelligence': 'EI is readiness for relationship',
        'singles_journey_01_identity_self_worth': 'Worth is foundation for readiness',
        'singles_journey_07_secure_confidence': 'Security enables emotional readiness',
        'singles_journey_03_healing_past_wounds': 'Healing is readiness work'
    },
    'emotional_regulation': {
        'singles_journey_05_emotional_readiness': 'Emotional readiness includes regulation',
        'singles_journey_06_emotional_intelligence': 'Regulation is part of EI',
        'singles_journey_04_family_patterns': 'Family patterns dominate regulation',
        'singles_journey_10_communicate_better': 'Regulation enables communication',
        'singles_journey_03_healing_past_wounds': 'Past wounds dysregulate us'
    },
    'emotional_intelligence': {
        'singles_journey_06_emotional_intelligence': 'Directly instructs emotional intelligence',
        'singles_journey_05_emotional_readiness': 'Readiness requires EI',
        'singles_journey_10_communicate_better': 'EI enables better communication',
        'singles_journey_08_toxic_triggers': 'Recognizing triggers requires EI'
    },
    'family_background_learned_patterns': {
        'singles_journey_03_healing_past_wounds': 'Past wounds from family need healing',
        'singles_journey_04_family_patterns': 'Directly focused on family patterns',
        'singles_journey_07_secure_confidence': 'Confident adulthood transcends family patterns',
        'singles_journey_14_compatibility': 'Partner choice is shaped by family patterns'
    },
    'hard_season_coping': {
        'singles_journey_04_family_patterns': 'Family patterns shape stress response',
        'singles_journey_05_emotional_readiness': 'Readiness includes resilience',
        'singles_journey_06_emotional_intelligence': 'EI helps navigate hard seasons',
        'singles_journey_17_faith_alignment': 'Faith sustains through struggles',
        'singles_journey_03_healing_past_wounds': 'Past trauma affects coping'
    },
    'identity_and_worth': {
        'singles_journey_01_identity_self_worth': 'Directly addresses identity and worth',
        'singles_journey_09_biblical_femininity': 'Biblical identity shapes worth',
        'singles_journey_09_biblical_masculinity': 'Biblical identity shapes worth',
        'singles_journey_07_secure_confidence': 'Secure identity grows confidence'
    },
    'relational_boundaries': {
        'singles_journey_11_healthy_boundaries': 'Healthy boundaries are core',
        'singles_journey_18_purity': 'Purity requires boundaries',
        'singles_journey_08_toxic_triggers': 'Protection from toxic people',
        'singles_journey_10_communicate_better': 'Communicate boundaries clearly',
        'singles_journey_05_emotional_readiness': 'Boundaries protect emotional readiness'
    },
    'relational_health': {
        'singles_journey_14_compatibility': 'Health includes good fit',
        'singles_journey_16_sexual_chemistry': 'Physical health matters too',
        'singles_journey_10_communicate_better': 'Communication creates health',
        'singles_journey_11_healthy_boundaries': 'Boundaries protect health',
        'singles_journey_06_emotional_intelligence': 'EI supports relational health'
    },
    'relational_readiness': {
        'singles_journey_01_identity_self_worth': 'Know yourself before relationship',
        'singles_journey_05_emotional_readiness': 'Emotional readiness is relational readiness',
        'singles_journey_14_compatibility': 'Ready when well-matched',
        'singles_journey_20_fear_commitment': 'Readiness requires overcoming fear',
        'singles_journey_19_choosing_spouse': 'Choosing wisely indicates readiness'
    },
    'relational_self_awareness': {
        'singles_journey_01_identity_self_worth': 'Understand your identity first',
        'singles_journey_06_emotional_intelligence': 'EI includes self-awareness',
        'singles_journey_10_communicate_better': 'Self-awareness enables communication',
        'singles_journey_05_emotional_readiness': 'Readiness enhances self-awareness'
    },
    'relational_expectations': {
        'singles_journey_02_cultural_lies': 'Expectations shaped by cultural lies',
        'singles_journey_14_compatibility': 'Expectations must align with partner',
        'singles_journey_19_choosing_spouse': 'Realistic expectations in choosing',
        'singles_journey_16_sexual_chemistry': 'Expectations about physical relationship'
    },
    'sacrifice_readiness': {
        'singles_journey_15_dating_purpose': 'Purpose includes sacrificial thinking',
        'singles_journey_19_choosing_spouse': 'Choosing requires sacrifice readiness',
        'singles_journey_17_faith_alignment': 'Faith informs sacrificial love',
        'singles_journey_14_compatibility': 'Compatibility means shared sacrifice values'
    },
    'spiritual_consistency': {
        'singles_journey_17_faith_alignment': 'Directly grows spiritual alignment',
        'singles_journey_07_secure_confidence': 'Spiritual confidence matures us',
        'singles_journey_02_cultural_lies': 'Spiritual perspective deconstructs lies',
        'singles_journey_18_purity': 'Purity is spiritual practice',
        'singles_journey_19_choosing_spouse': 'Spiritual maturity guides choice'
    },
    'spiritual_leadership_understanding': {
        'singles_journey_02_cultural_lies': 'Deconstructing false models of leadership',
        'singles_journey_17_faith_alignment': 'Faith alignment includes leadership understanding',
        'singles_journey_14_compatibility': 'Compatibility in leadership vision'
    },
    'trigger_handling': {
        'singles_journey_03_healing_past_wounds': 'Healing reduces trigger reactivity',
        'singles_journey_04_family_patterns': 'Family patterns drive triggers',
        'singles_journey_08_toxic_triggers': 'Directly addresses toxic triggers',
        'singles_journey_06_emotional_intelligence': 'EI helps recognize and manage triggers',
        'singles_journey_05_emotional_readiness': 'Readiness includes handling triggers'
    },
    'unresolved_wounds': {
        'singles_journey_03_healing_past_wounds': 'Core healing for unresolved wounds',
        'singles_journey_04_family_patterns': 'Family wounds need processing',
        'singles_journey_01_identity_self_worth': 'Worth restored through healing',
        'singles_journey_07_secure_confidence': 'Confidence grows from healed wounds',
        'singles_journey_17_faith_alignment': 'Spiritual healing of deep wounds'
    }
}

# Build singlesReadiness config section
singlesReadiness = {
    'assessmentId': 'singles_readiness',
    'audience': 'single_never_married',
    'dimensionMappings': []
}

for dim in dimensions:
    dim_id = dim['id']
    dim_name = dim['name']
    journeys_for_dim = dimension_to_journeys.get(dim_id, [])
    
    recommendations = []
    for j_id in journeys_for_dim:
        rationale = (rationales.get(dim_id, {}).get(j_id, f'Support for {dim_name}') 
                    if dim_id in rationales else f'Journey supports {dim_name}')
        recommendations.append({
            'journeyId': j_id,
            'journeyTitle': journey_titles.get(j_id, j_id),
            'rationale': rationale
        })
    
    singlesReadiness['dimensionMappings'].append({
        'dimensionId': dim_id,
        'dimensionName': dim_name,
        'recommendations': recommendations
    })

# Save to JSON file
output_file = '/tmp/singlesReadiness_section.json'
with open(output_file, 'w') as f:
    json.dump(singlesReadiness, f, indent=2)

print(f"\n\nGenerated singlesReadiness section saved to {output_file}")
print(f"Total dimensions: {len(singlesReadiness['dimensionMappings'])}")
for m in singlesReadiness['dimensionMappings']:
    print(f"  {m['dimensionId']:40s}: {len(m['recommendations'])} recommendations")
