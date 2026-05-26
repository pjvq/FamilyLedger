import 'package:flutter/material.dart';
import 'design_tokens.dart';

class AppTheme {
  AppTheme._();

  // ---- Light Theme ----
  // Use platform-default page transitions.
  // CupertinoPageTransitionsBuilder was removed from material.dart in Flutter 3.44.
  static const _pageTransitionsTheme = PageTransitionsTheme();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: ColorTokens.primary,
        scaffoldBackgroundColor: NeutralColorsLight.neutral1,
        pageTransitionsTheme: _pageTransitionsTheme,
        extensions: const [AppSemanticColors.light],
        cardTheme: CardThemeData(
          color: NeutralColorsLight.neutral0,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(RadiusTokens.lg)),
          ),
          margin: EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.xs,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: NeutralColorsLight.neutral1,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TypographyTokens.titleLg(
            color: NeutralColorsLight.neutral7,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: NeutralColorsLight.neutral0,
          selectedItemColor: ColorTokens.primary,
          unselectedItemColor: NeutralColorsLight.neutral5,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: NeutralColorsLight.neutral3,
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NeutralColorsLight.neutral2,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.base, // 16px — comfortable touch target
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorTokens.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RadiusTokens.md),
            ),
            textStyle: TypographyTokens.titleMd(),
          ),
        ),
      );

  // ---- Dark Theme ----
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: ColorTokens.primaryLight,
        scaffoldBackgroundColor: NeutralColorsDark.neutral0,
        pageTransitionsTheme: _pageTransitionsTheme,
        extensions: const [AppSemanticColors.dark],
        cardTheme: CardThemeData(
          color: NeutralColorsDark.neutral2,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(RadiusTokens.lg)),
          ),
          margin: EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.xs,
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: NeutralColorsDark.neutral0,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TypographyTokens.titleLg(
            color: NeutralColorsDark.neutral7,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: NeutralColorsDark.neutral2,
          selectedItemColor: ColorTokens.primaryLight,
          unselectedItemColor: NeutralColorsDark.neutral5,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        dividerTheme: DividerThemeData(
          color: NeutralColorsDark.neutral3,
          thickness: 0.5,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: NeutralColorsDark.neutral3,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusTokens.md),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: SpacingTokens.base,
            vertical: SpacingTokens.base, // 16px — comfortable touch target
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorTokens.primaryLight,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RadiusTokens.md),
            ),
            textStyle: TypographyTokens.titleMd(),
          ),
        ),
      );
}
