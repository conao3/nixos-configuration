{ ... }:
{
  home.file = {
    ".config" = {
      source = ./.config;
      recursive = true;
    };
    ".config/nrepl/nrepl.edn".source = ./nrepl.edn;
    ".config/fcitx5/config".text = ''
      [Hotkey]
      EnumerateWithTriggerKeys=True
      AltTriggerKeys=
      EnumerateForwardKeys=
      EnumerateBackwardKeys=
      EnumerateSkipFirst=False
      TogglePreedit=
      ModifierOnlyKeyTimeout=250

      [Hotkey/TriggerKeys]
      0=Alt+space

      [Hotkey/EnumerateGroupForwardKeys]
      0=Super+space

      [Hotkey/EnumerateGroupBackwardKeys]
      0=Shift+Super+space

      [Hotkey/ActivateKeys]
      0=Hangul_Hanja

      [Hotkey/DeactivateKeys]
      0=Hangul_Romaja

      [Hotkey/PrevPage]
      0=Up

      [Hotkey/NextPage]
      0=Down

      [Hotkey/PrevCandidate]
      0=Shift+Tab

      [Hotkey/NextCandidate]
      0=Tab

      [Behavior]
      ActiveByDefault=False
      resetStateWhenFocusIn=No
      ShareInputState=All
      PreeditEnabledByDefault=True
      ShowInputMethodInformation=True
      showInputMethodInformationWhenFocusIn=False
      CompactInputMethodInformation=True
      ShowFirstInputMethodInformation=True
      DefaultPageSize=5
      OverrideXkbOption=False
      CustomXkbOption=
      EnabledAddons=
      DisabledAddons=
      PreloadInputMethod=True
      AllowInputMethodForPassword=False
      ShowPreeditForPassword=False
      AutoSavePeriod=30
    '';
    ".config/fcitx5/conf/skk.conf".text = ''
      # Rule
      Rule=azik
      # Punctuation Style
      PunctuationStyle=Japanese
      # Initial Input Mode
      InitialInputMode=Hiragana
      # Page size
      PageSize=7
      # Candidate Layout
      Candidate Layout=Vertical
      # Return-key does not insert new line on commit
      EggLikeNewLine=True
      # Show Annotation
      ShowAnnotation=True
      # Candidate Key
      CandidateChooseKey="Digit (0,1,2,...)"
      # Number candidate of Triggers To Show Candidate Window
      NTriggersToShowCandWin=4

      [CandidatesPageUpKey]
      0=Page_Up

      [CandidatesPageDownKey]
      0=Next

      [CursorUp]
      0=Up

      [CursorDown]
      0=Down
    '';
  };
}
