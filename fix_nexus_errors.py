#!/usr/bin/env python3
"""
Nexus App Error Fixer
Automatically fixes all Dart compilation errors in the Nexus app
"""

import os
import re
import sys

def fix_pubspec_yaml(project_path):
    """Add missing google_sign_in dependency"""
    pubspec_path = os.path.join(project_path, 'pubspec.yaml')
    
    with open(pubspec_path, 'r') as f:
        content = f.read()
    
    # Check if google_sign_in is already there
    if 'google_sign_in:' not in content:
        print("✓ Adding google_sign_in to pubspec.yaml")
        
        # Find the dependencies section and add google_sign_in
        # Add it after firebase_core line
        content = content.replace(
            'firebase_core: ^4.3.0',
            'firebase_core: ^4.3.0\n  google_sign_in: ^6.2.1'
        )
        
        with open(pubspec_path, 'w') as f:
            f.write(content)
    else:
        print("✓ google_sign_in already in pubspec.yaml")

def fix_journey_provider(project_path):
    """Fix duplicate allJourneyProgressProvider declaration"""
    file_path = os.path.join(project_path, 'lib/core/providers/journey_provider.dart')
    
    with open(file_path, 'r') as f:
        lines = f.readlines()
    
    print("✓ Fixing duplicate allJourneyProgressProvider in journey_provider.dart")
    
    # Find and remove the second declaration (around line 190)
    new_lines = []
    found_first = False
    skip_until_brace = False
    
    for i, line in enumerate(lines):
        if 'final allJourneyProgressProvider = FutureProvider' in line and found_first:
            skip_until_brace = True
            continue
        
        if 'final allJourneyProgressProvider = StreamProvider' in line:
            found_first = True
        
        if skip_until_brace:
            if '});' in line:
                skip_until_brace = False
            continue
        
        new_lines.append(line)
    
    with open(file_path, 'w') as f:
        f.writelines(new_lines)

def fix_firestore_service(project_path):
    """Fix duplicate getUser and updateUserFields declarations"""
    file_path = os.path.join(project_path, 'lib/core/services/firestore_service.dart')
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    print("✓ Fixing duplicate methods in firestore_service.dart")
    
    # Remove the duplicate getUser method (around line 533)
    # Remove everything from line 533 to the closing brace
    pattern = r'\/\/ Duplicate getUser.*?Future<UserModel\?> getUser\(String userId\) async \{.*?\n  \}'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # Remove duplicate updateUserFields (around line 553)
    pattern = r'\/\/ Duplicate updateUserFields.*?Future<void> updateUserFields\(String userId, Map<String, dynamic> fields\) async \{.*?\n  \}'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    with open(file_path, 'w') as f:
        f.write(content)

def fix_user_model(project_path):
    """Add missing fromFirestore and toFirestore methods to UserModel"""
    file_path = os.path.join(project_path, 'lib/core/models/user_model.dart')
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    print("✓ Adding missing methods to UserModel")
    
    # Check if methods already exist
    if 'fromFirestore' not in content:
        # Find the last closing brace of the class
        insert_position = content.rfind('}')
        
        methods = '''
  // Firestore serialization
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      age: data['age'],
      gender: data['gender'],
      city: data['city'],
      country: data['country'],
      profileUrl: data['profileUrl'],
      photos: data['photos'] != null ? List<String>.from(data['photos']) : null,
      hobbies: data['hobbies'] != null ? List<String>.from(data['hobbies']) : null,
      profession: data['profession'],
      educationLevel: data['educationLevel'],
      relationshipWithGod: data['relationshipWithGod'],
      phoneNumber: data['phoneNumber'],
      blocked: data['blocked'] != null ? List<String>.from(data['blocked']) : null,
      nexus2: data['nexus2'] != null ? Nexus2Data.fromMap(data['nexus2']) : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'age': age,
      'gender': gender,
      'city': city,
      'country': country,
      'profileUrl': profileUrl,
      'photos': photos,
      'hobbies': hobbies,
      'profession': profession,
      'educationLevel': educationLevel,
      'relationshipWithGod': relationshipWithGod,
      'phoneNumber': phoneNumber,
      'blocked': blocked,
      if (nexus2 != null) 'nexus2': nexus2!.toMap(),
    };
  }
'''
        content = content[:insert_position] + methods + content[insert_position:]
        
        with open(file_path, 'w') as f:
            f.write(content)

def fix_assessment_model(project_path):
    """Add missing fromFirestore methods to AssessmentResult"""
    file_path = os.path.join(project_path, 'lib/core/models/assessment_model.dart')
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    print("✓ Adding missing methods to AssessmentResult")
    
    if 'AssessmentResult.fromFirestore' not in content:
        # Find the AssessmentResult class and add the method
        pattern = r'(class AssessmentResult \{.*?)(  AssessmentResult\()'
        
        method = '''  factory AssessmentResult.fromFirestore(Map<String, dynamic> data) {
    return AssessmentResult(
      id: data['id'] ?? '',
      assessmentId: data['assessmentId'] ?? '',
      userId: data['userId'] ?? '',
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dimensionScores: (data['dimensionScores'] as Map<String, dynamic>?)?.map(
        (key, value) => MapEntry(key, DimensionScore.fromMap(value)),
      ) ?? {},
      overallScore: (data['overallScore'] ?? 0).toDouble(),
      overallPercentage: (data['overallPercentage'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'assessmentId': assessmentId,
      'userId': userId,
      'completedAt': Timestamp.fromDate(completedAt),
      'dimensionScores': dimensionScores.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'overallScore': overallScore,
      'overallPercentage': overallPercentage,
    };
  }

  '''
        
        content = re.sub(pattern, r'\1' + method + r'\2', content, flags=re.DOTALL)
        
        with open(file_path, 'w') as f:
            f.write(content)

def fix_journey_model(project_path):
    """Add missing fromFirestore and id parameter to JourneyProgress"""
    file_path = os.path.join(project_path, 'lib/core/models/journey_model.dart')
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    print("✓ Adding missing methods to JourneyProgress")
    
    # Add id parameter if missing
    if 'required this.id' not in content:
        content = content.replace(
            'const JourneyProgress({',
            'const JourneyProgress({\n    required this.id,'
        )
        content = content.replace(
            'class JourneyProgress {',
            'class JourneyProgress {\n  final String id;'
        )
    
    # Add fromFirestore if missing
    if 'JourneyProgress.fromFirestore' not in content:
        method = '''
  factory JourneyProgress.fromFirestore(Map<String, dynamic> data) {
    return JourneyProgress(
      id: data['id'] ?? '',
      productId: data['productId'] ?? '',
      userId: data['userId'] ?? '',
      startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastAccessedAt: (data['lastAccessedAt'] as Timestamp?)?.toDate(),
      currentSessionNumber: data['currentSessionNumber'] ?? 1,
      completedSessionIds: data['completedSessionIds'] != null 
        ? List<String>.from(data['completedSessionIds']) 
        : [],
      status: data['status'] ?? 'active',
    );
  }

  factory JourneyProgress.fromMap(Map<String, dynamic> data) {
    return JourneyProgress.fromFirestore(data);
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'productId': productId,
      'userId': userId,
      'startedAt': Timestamp.fromDate(startedAt),
      'lastAccessedAt': lastAccessedAt != null ? Timestamp.fromDate(lastAccessedAt!) : null,
      'currentSessionNumber': currentSessionNumber,
      'completedSessionIds': completedSessionIds,
      'status': status,
    };
  }
'''
        # Find the class end and insert before it
        insert_pos = content.find('class JourneyProgress {')
        insert_pos = content.find('}', insert_pos)
        content = content[:insert_pos] + method + '\n' + content[insert_pos:]
    
    with open(file_path, 'w') as f:
        f.write(content)

def fix_story_model(project_path):
    """Add missing methods to story models"""
    file_path = os.path.join(project_path, 'lib/core/models/story_model.dart')
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    print("✓ Adding missing methods to story models")
    
    # Add StoryProgress.fromFirestore if missing
    if 'StoryProgress.fromFirestore' not in content:
        method = '''
  factory StoryProgress.fromFirestore(Map<String, dynamic> data) {
    return StoryProgress(
      storyId: data['storyId'] ?? '',
      userId: data['userId'] ?? '',
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      saved: data['saved'] ?? false,
      reflectionCompleted: data['reflectionCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'storyId': storyId,
      'userId': userId,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'saved': saved,
      'reflectionCompleted': reflectionCompleted,
    };
  }
'''
        # Find StoryProgress class
        insert_pos = content.find('class StoryProgress {')
        if insert_pos != -1:
            insert_pos = content.find('}', insert_pos)
            content = content[:insert_pos] + method + '\n' + content[insert_pos:]
    
    # Add PollVote.fromFirestore if missing
    if 'PollVote.fromFirestore' not in content:
        # Add id parameter to PollVote first
        content = content.replace(
            'const PollVote({',
            'const PollVote({\n    required this.id,'
        )
        content = content.replace(
            'class PollVote {',
            'class PollVote {\n  final String id;'
        )
        
        method = '''
  factory PollVote.fromFirestore(Map<String, dynamic> data) {
    return PollVote(
      id: data['id'] ?? '',
      pollId: data['pollId'] ?? '',
      userId: data['userId'] ?? '',
      selectedOptionId: data['selectedOptionId'] ?? '',
      votedAt: (data['votedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'pollId': pollId,
      'userId': userId,
      'selectedOptionId': selectedOptionId,
      'votedAt': Timestamp.fromDate(votedAt),
    };
  }
'''
        insert_pos = content.find('class PollVote {')
        if insert_pos != -1:
            insert_pos = content.find('}', insert_pos)
            content = content[:insert_pos] + method + '\n' + content[insert_pos:]
    
    with open(file_path, 'w') as f:
        f.write(content)

def fix_session_response_model(project_path):
    """Add id parameter and methods to SessionResponse"""
    file_path = os.path.join(project_path, 'lib/core/models/journey_model.dart')
    
    with open(file_path, 'r') as f:
        content = f.read()
    
    print("✓ Fixing SessionResponse model")
    
    # Add id parameter
    if 'class SessionResponse {' in content and 'final String id;' not in content.split('class SessionResponse {')[1].split('SessionResponse({')[0]:
        content = content.replace(
            'class SessionResponse {',
            'class SessionResponse {\n  final String id;'
        )
        content = content.replace(
            'const SessionResponse({',
            'const SessionResponse({\n    required this.id,'
        )
    
    # Add fromFirestore method
    if 'SessionResponse.fromFirestore' not in content:
        method = '''
  factory SessionResponse.fromFirestore(Map<String, dynamic> data) {
    return SessionResponse(
      id: data['id'] ?? '',
      sessionNumber: data['sessionNumber'] ?? 0,
      userId: data['userId'] ?? '',
      productId: data['productId'] ?? '',
      completedAt: (data['completedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      responseData: data['responseData'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'sessionNumber': sessionNumber,
      'userId': userId,
      'productId': productId,
      'completedAt': Timestamp.fromDate(completedAt),
      'responseData': responseData,
    };
  }
'''
        # Find SessionResponse class and add method
        insert_pos = content.find('class SessionResponse {')
        if insert_pos != -1:
            # Find the constructor closing brace
            insert_pos = content.find('});', insert_pos) + 3
            content = content[:insert_pos] + '\n' + method + content[insert_pos:]
    
    with open(file_path, 'w') as f:
        f.write(content)

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 fix_nexus_errors.py /path/to/nexus_app")
        sys.exit(1)
    
    project_path = sys.argv[1]
    
    if not os.path.exists(project_path):
        print(f"Error: Project path {project_path} does not exist")
        sys.exit(1)
    
    print("🔧 Starting Nexus App Error Fixer...\n")
    
    try:
        fix_pubspec_yaml(project_path)
        fix_journey_provider(project_path)
        fix_firestore_service(project_path)
        fix_user_model(project_path)
        fix_assessment_model(project_path)
        fix_journey_model(project_path)
        fix_story_model(project_path)
        fix_session_response_model(project_path)
        
        print("\n✅ All fixes applied successfully!")
        print("\n📦 Running flutter pub get...")
        
        os.chdir(project_path)
        os.system('flutter pub get')
        
        print("\n🎉 Done! Try running your app now:")
        print("   cd", project_path)
        print("   flutter run")
        
    except Exception as e:
        print(f"\n❌ Error occurred: {str(e)}")
        sys.exit(1)

if __name__ == '__main__':
    main()
