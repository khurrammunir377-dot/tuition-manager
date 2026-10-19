import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add import 'quran_screen.dart'; if not already present
if "import 'quran_screen.dart';" not in content:
    content = content.replace("import 'firebase_options.dart';", "import 'firebase_options.dart';\nimport 'quran_screen.dart';")

# 2. Add teachingMode to Store
store_addition = """  String teachingMode = 'all'; // 'all', 'physical', 'online'

  void setTeachingMode(String m) {
    teachingMode = m;
    notifyListeners();
  }

  List<Student> get filteredStudents {
    if (teachingMode == 'physical') return students.where((s) => !s.isOnline).toList();
    if (teachingMode == 'online') return students.where((s) => s.isOnline).toList();
    return students;
  }
"""

if "String teachingMode = 'all';" not in content:
    content = content.replace(
        "class Store extends ChangeNotifier {\n  String center = 'میرا ٹیوشن و قرآن سینٹر';",
        f"class Store extends ChangeNotifier {{\n  String center = 'میرا ٹیوشن و قرآن سینٹر';\n{store_addition}"
    )

# 3. Enhance TuitionApp themes for rich, vibrant, premium colors
old_theme = """        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF0F7B5F),
          useMaterial3: true,
          fontFamily: 'sans-serif',
          cardTheme: CardThemeData(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF0F7B5F),
          brightness: Brightness.dark,
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),"""

new_theme = """        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            primary: const Color(0xFF0F766E),
            secondary: const Color(0xFFD97706),
            surface: const Color(0xFFF8FAFC),
          ),
          useMaterial3: true,
          fontFamily: 'sans-serif',
          scaffoldBackgroundColor: const Color(0xFFF1F5F9),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF064E3B),
            foregroundColor: Colors.white,
            elevation: 1,
            centerTitle: false,
            iconTheme: IconThemeData(color: Colors.white),
            actionsIconTheme: IconThemeData(color: Colors.white),
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shadowColor: Colors.black12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0F766E),
            brightness: Brightness.dark,
            primary: const Color(0xFF14B8A6),
            secondary: const Color(0xFFF59E0B),
            surface: const Color(0xFF0F172A),
          ),
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFF0B0F19),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF022C22),
            foregroundColor: Colors.white,
            elevation: 1,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
          ),
          inputDecorationTheme: InputDecorationTheme(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),"""

content = content.replace(old_theme, new_theme)

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Step 1 and 2 updated successfully")
