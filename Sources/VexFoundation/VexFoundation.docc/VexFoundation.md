@Metadata {
    @DisplayName("VexFoundation")
}

# ``VexFoundation``

Typed music notation rendering in Swift, based on VexFlow concepts.

VexFoundation keeps familiar concepts like ``Factory``, ``System``, ``Voice``, notes, modifiers, and connectors, while preferring typed models such as ``StaffKeySpec``, ``NoteDurationSpec``, and ``TimeSignatureSpec``.

## Start Here

1. <doc:GettingStarted>
2. <doc:TypedAPIBasics>
3. <doc:EasyScoreBasics>
4. <doc:AdvancedNotation>

## Coverage

- <doc:CoverageLedger>

## Topics

### Setup

- <doc:InstallationAndPlatformSupport>
- <doc:RenderingAndFonts>
- ``FactoryOptions``
- ``SystemOptions``

### Core Workflow

- <doc:FactorySystemVoiceModel>
- ``Factory``
- ``Factory/draw()``
- ``System``
- ``System/format()``
- ``SystemStave``
- ``Voice``
- ``Voice/addTickables(_:)``

### Typed Data Model

- <doc:TypedModels>
- ``StaffKeySpec``
- ``NoteDurationSpec``
- ``TimeSignatureSpec``
- ``NonEmptyArray``

### Parsing and EasyScore

- <doc:EasyScoreGrammarAndOptions>
- ``EasyScore``
- ``Factory/EasyScore(options:)``
- ``EasyScore/notes(_:options:)``
- ``EasyScoreOptions``
- ``EasyScoreDefaults``
- ``Parser``

### Notation Features

- <doc:StavesAndModifiers>
- <doc:ConnectorsAndExpressiveMarks>
- <doc:TablatureGuide>
- ``Stave``
- ``StaveNote``
- ``Factory/StaveNote(_:)``
- ``Beam``
- ``Tuplet``

### Utilities and Behavior

- <doc:TheoryUtilities>
- <doc:ErrorHandlingAndPreconditions>
- <doc:Troubleshooting>
- <doc:VexFlowParityAndMigration>
