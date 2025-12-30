import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_pl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('pl')
  ];

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @flashcards.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcards;

  /// No description provided for @flashcardsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and study flashcard decks to boost your learning'**
  String get flashcardsDescription;

  /// No description provided for @chat.
  ///
  /// In en, this message translates to:
  /// **'Chat'**
  String get chat;

  /// No description provided for @login_register.
  ///
  /// In en, this message translates to:
  /// **'Login / Register'**
  String get login_register;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @hide_panel.
  ///
  /// In en, this message translates to:
  /// **'Hide panel'**
  String get hide_panel;

  /// No description provided for @show_panel.
  ///
  /// In en, this message translates to:
  /// **'Show panel'**
  String get show_panel;

  /// No description provided for @settings_saved_successfully.
  ///
  /// In en, this message translates to:
  /// **'Settings saved successfully.'**
  String get settings_saved_successfully;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Select language'**
  String get language;

  /// No description provided for @dark_mode.
  ///
  /// In en, this message translates to:
  /// **'Dark mode'**
  String get dark_mode;

  /// No description provided for @dark_mode_description.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable dark mode'**
  String get dark_mode_description;

  /// No description provided for @save_changes.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get save_changes;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @polish.
  ///
  /// In en, this message translates to:
  /// **'Polish'**
  String get polish;

  /// No description provided for @spanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get spanish;

  /// No description provided for @french.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get french;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get german;

  /// No description provided for @manage_files.
  ///
  /// In en, this message translates to:
  /// **'Manage files'**
  String get manage_files;

  /// No description provided for @manage_uploaded_files.
  ///
  /// In en, this message translates to:
  /// **'Manage uploaded files'**
  String get manage_uploaded_files;

  /// No description provided for @file_description.
  ///
  /// In en, this message translates to:
  /// **'File description'**
  String get file_description;

  /// No description provided for @enter_file_description.
  ///
  /// In en, this message translates to:
  /// **'Enter file description'**
  String get enter_file_description;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @enter_category.
  ///
  /// In en, this message translates to:
  /// **'Enter category'**
  String get enter_category;

  /// No description provided for @start_page.
  ///
  /// In en, this message translates to:
  /// **'Start page'**
  String get start_page;

  /// No description provided for @end_page.
  ///
  /// In en, this message translates to:
  /// **'End page'**
  String get end_page;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @uploaded_files.
  ///
  /// In en, this message translates to:
  /// **'Uploaded files'**
  String get uploaded_files;

  /// No description provided for @no_files_uploaded_yet.
  ///
  /// In en, this message translates to:
  /// **'No files uploaded yet.'**
  String get no_files_uploaded_yet;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading...'**
  String get uploading;

  /// No description provided for @upload_new_file.
  ///
  /// In en, this message translates to:
  /// **'Upload new file'**
  String get upload_new_file;

  /// No description provided for @error_file_description_required.
  ///
  /// In en, this message translates to:
  /// **'File description is required.'**
  String get error_file_description_required;

  /// No description provided for @error_category_required.
  ///
  /// In en, this message translates to:
  /// **'Category is required.'**
  String get error_category_required;

  /// No description provided for @error_fetch_files.
  ///
  /// In en, this message translates to:
  /// **'An error occurred while fetching uploaded files.'**
  String get error_fetch_files;

  /// No description provided for @loading_decks.
  ///
  /// In en, this message translates to:
  /// **'Loading decks...'**
  String get loading_decks;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @errorOccurred.
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get errorOccurred;

  /// No description provided for @try_again.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get try_again;

  /// No description provided for @welcome_flashcards.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Flashcards!'**
  String get welcome_flashcards;

  /// No description provided for @get_started_create_deck.
  ///
  /// In en, this message translates to:
  /// **'Get started by creating your first deck.'**
  String get get_started_create_deck;

  /// No description provided for @no_flashcard_decks.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have any flashcard decks yet. Create a new deck to start learning!'**
  String get no_flashcard_decks;

  /// No description provided for @create_your_first_deck.
  ///
  /// In en, this message translates to:
  /// **'Create your first deck'**
  String get create_your_first_deck;

  /// No description provided for @createDeck.
  ///
  /// In en, this message translates to:
  /// **'Create Deck'**
  String get createDeck;

  /// No description provided for @create_new_deck.
  ///
  /// In en, this message translates to:
  /// **'Create new deck'**
  String get create_new_deck;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @study.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get study;

  /// No description provided for @flashcards_tooltip.
  ///
  /// In en, this message translates to:
  /// **'Need flashcards? Chat can help you create study-ready flashcards in seconds.'**
  String get flashcards_tooltip;

  /// No description provided for @more_information.
  ///
  /// In en, this message translates to:
  /// **'More information'**
  String get more_information;

  /// No description provided for @no_flashcards_available.
  ///
  /// In en, this message translates to:
  /// **'No flashcards available'**
  String get no_flashcards_available;

  /// No description provided for @deck_has_no_flashcards.
  ///
  /// In en, this message translates to:
  /// **'This deck doesn\'t contain any flashcards yet.'**
  String get deck_has_no_flashcards;

  /// No description provided for @back_to_decks.
  ///
  /// In en, this message translates to:
  /// **'Back to decks'**
  String get back_to_decks;

  /// No description provided for @congratulations.
  ///
  /// In en, this message translates to:
  /// **'Congratulations!'**
  String get congratulations;

  /// No description provided for @completed_flashcards.
  ///
  /// In en, this message translates to:
  /// **'You\'ve completed all flashcards in this deck.'**
  String get completed_flashcards;

  /// No description provided for @reset_deck.
  ///
  /// In en, this message translates to:
  /// **'Reset deck'**
  String get reset_deck;

  /// No description provided for @exit_study.
  ///
  /// In en, this message translates to:
  /// **'Exit study'**
  String get exit_study;

  /// No description provided for @card_counter.
  ///
  /// In en, this message translates to:
  /// **'Card {current} of {total}'**
  String card_counter(Object current, Object total);

  /// No description provided for @type_message.
  ///
  /// In en, this message translates to:
  /// **'Type your message...'**
  String get type_message;

  /// No description provided for @writing_response.
  ///
  /// In en, this message translates to:
  /// **'Writing response...'**
  String get writing_response;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @new_conversation.
  ///
  /// In en, this message translates to:
  /// **'New conversation'**
  String get new_conversation;

  /// No description provided for @edit_title.
  ///
  /// In en, this message translates to:
  /// **'Edit title'**
  String get edit_title;

  /// No description provided for @new_title.
  ///
  /// In en, this message translates to:
  /// **'New title'**
  String get new_title;

  /// No description provided for @delete_conversation.
  ///
  /// In en, this message translates to:
  /// **'Delete conversation'**
  String get delete_conversation;

  /// No description provided for @confirm_delete_title.
  ///
  /// In en, this message translates to:
  /// **'Confirm deletion'**
  String get confirm_delete_title;

  /// No description provided for @confirm_delete_description.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this conversation? This action cannot be undone.'**
  String get confirm_delete_description;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @add_flashcard.
  ///
  /// In en, this message translates to:
  /// **'Add flashcard'**
  String get add_flashcard;

  /// No description provided for @edit_deck.
  ///
  /// In en, this message translates to:
  /// **'Edit deck'**
  String get edit_deck;

  /// No description provided for @editDeck.
  ///
  /// In en, this message translates to:
  /// **'Edit Deck'**
  String get editDeck;

  /// No description provided for @deck_name.
  ///
  /// In en, this message translates to:
  /// **'Deck name'**
  String get deck_name;

  /// No description provided for @deckName.
  ///
  /// In en, this message translates to:
  /// **'Deck Name'**
  String get deckName;

  /// No description provided for @enter_deck_name.
  ///
  /// In en, this message translates to:
  /// **'Enter deck name'**
  String get enter_deck_name;

  /// No description provided for @deck_description.
  ///
  /// In en, this message translates to:
  /// **'Deck description'**
  String get deck_description;

  /// No description provided for @enter_deck_description.
  ///
  /// In en, this message translates to:
  /// **'Enter deck description'**
  String get enter_deck_description;

  /// No description provided for @flashcard_number.
  ///
  /// In en, this message translates to:
  /// **'Flashcard number {number}'**
  String flashcard_number(Object number);

  /// No description provided for @question.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get question;

  /// No description provided for @enter_question.
  ///
  /// In en, this message translates to:
  /// **'Enter question'**
  String get enter_question;

  /// No description provided for @answer.
  ///
  /// In en, this message translates to:
  /// **'Answer'**
  String get answer;

  /// No description provided for @enter_answer.
  ///
  /// In en, this message translates to:
  /// **'Enter answer'**
  String get enter_answer;

  /// No description provided for @modern_homepage_title.
  ///
  /// In en, this message translates to:
  /// **'Where your learning begins and ends'**
  String get modern_homepage_title;

  /// No description provided for @modern_homepage_subtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect the world of exams, flashcards and intelligent chat in one place.'**
  String get modern_homepage_subtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @email_placeholder.
  ///
  /// In en, this message translates to:
  /// **'m@example.com'**
  String get email_placeholder;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirm_password.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirm_password;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @tests.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get tests;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @searchDecks.
  ///
  /// In en, this message translates to:
  /// **'Search decks...'**
  String get searchDecks;

  /// No description provided for @cards.
  ///
  /// In en, this message translates to:
  /// **'cards'**
  String get cards;

  /// No description provided for @shared.
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get shared;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @addByCode.
  ///
  /// In en, this message translates to:
  /// **'Add by Code'**
  String get addByCode;

  /// No description provided for @manageShares.
  ///
  /// In en, this message translates to:
  /// **'Manage Shares'**
  String get manageShares;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @cardCount.
  ///
  /// In en, this message translates to:
  /// **'Card Count'**
  String get cardCount;

  /// No description provided for @recent.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recent;

  /// No description provided for @lastSession.
  ///
  /// In en, this message translates to:
  /// **'Last Session'**
  String get lastSession;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @deleteDeck.
  ///
  /// In en, this message translates to:
  /// **'Delete Deck'**
  String get deleteDeck;

  /// No description provided for @deleteDeckConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This cannot be undone.'**
  String deleteDeckConfirm(String name);

  /// No description provided for @deckDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deck deleted'**
  String get deckDeleted;

  /// No description provided for @removeSharedDeck.
  ///
  /// In en, this message translates to:
  /// **'Remove Shared Deck'**
  String get removeSharedDeck;

  /// No description provided for @removeSharedDeckConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this shared deck from your library?'**
  String get removeSharedDeckConfirm;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @removeFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Remove from library'**
  String get removeFromLibrary;

  /// No description provided for @showAnswer.
  ///
  /// In en, this message translates to:
  /// **'Show Answer'**
  String get showAnswer;

  /// No description provided for @tapToFlip.
  ///
  /// In en, this message translates to:
  /// **'Tap to flip'**
  String get tapToFlip;

  /// No description provided for @hard.
  ///
  /// In en, this message translates to:
  /// **'Hard'**
  String get hard;

  /// No description provided for @tryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get tryAgain;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @reviewLater.
  ///
  /// In en, this message translates to:
  /// **'Review later'**
  String get reviewLater;

  /// No description provided for @easy.
  ///
  /// In en, this message translates to:
  /// **'Easy'**
  String get easy;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get gotIt;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @sessionComplete.
  ///
  /// In en, this message translates to:
  /// **'Session Complete!'**
  String get sessionComplete;

  /// No description provided for @cardsReviewed.
  ///
  /// In en, this message translates to:
  /// **'You reviewed {count} cards'**
  String cardsReviewed(String count);

  /// No description provided for @nextSession.
  ///
  /// In en, this message translates to:
  /// **'Next session: {date}'**
  String nextSession(String date);

  /// No description provided for @retakeHardCards.
  ///
  /// In en, this message translates to:
  /// **'Retake Hard Cards'**
  String get retakeHardCards;

  /// No description provided for @retakeSession.
  ///
  /// In en, this message translates to:
  /// **'Retake Session'**
  String get retakeSession;

  /// No description provided for @saveAndExit.
  ///
  /// In en, this message translates to:
  /// **'Save & Exit'**
  String get saveAndExit;

  /// No description provided for @backToDecks.
  ///
  /// In en, this message translates to:
  /// **'Back to Decks'**
  String get backToDecks;

  /// No description provided for @noCardsToRetake.
  ///
  /// In en, this message translates to:
  /// **'No cards to retake'**
  String get noCardsToRetake;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @noHardCardsFound.
  ///
  /// In en, this message translates to:
  /// **'No hard cards found'**
  String get noHardCardsFound;

  /// No description provided for @addDeckByCode.
  ///
  /// In en, this message translates to:
  /// **'Add Deck by Code'**
  String get addDeckByCode;

  /// No description provided for @shareCode.
  ///
  /// In en, this message translates to:
  /// **'Share Code'**
  String get shareCode;

  /// No description provided for @alreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'Already in your library'**
  String get alreadyAdded;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @deckAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Deck added successfully'**
  String get deckAddedSuccessfully;

  /// No description provided for @noSharedDecks.
  ///
  /// In en, this message translates to:
  /// **'No shared decks yet'**
  String get noSharedDecks;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get description;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @addCard.
  ///
  /// In en, this message translates to:
  /// **'Add Card'**
  String get addCard;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @testsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create and take practice exams to test your knowledge'**
  String get testsDescription;

  /// No description provided for @searchExams.
  ///
  /// In en, this message translates to:
  /// **'Search exams...'**
  String get searchExams;

  /// No description provided for @welcomeTests.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Tests'**
  String get welcomeTests;

  /// No description provided for @getStartedCreateTest.
  ///
  /// In en, this message translates to:
  /// **'Create your first exam or add one using a share code'**
  String get getStartedCreateTest;

  /// No description provided for @createExam.
  ///
  /// In en, this message translates to:
  /// **'Create Exam'**
  String get createExam;

  /// No description provided for @editExam.
  ///
  /// In en, this message translates to:
  /// **'Edit Exam'**
  String get editExam;

  /// No description provided for @deleteExam.
  ///
  /// In en, this message translates to:
  /// **'Delete Exam'**
  String get deleteExam;

  /// No description provided for @examDeleted.
  ///
  /// In en, this message translates to:
  /// **'Exam deleted'**
  String get examDeleted;

  /// No description provided for @examName.
  ///
  /// In en, this message translates to:
  /// **'Exam Name'**
  String get examName;

  /// No description provided for @questions.
  ///
  /// In en, this message translates to:
  /// **'Questions'**
  String get questions;

  /// No description provided for @addQuestion.
  ///
  /// In en, this message translates to:
  /// **'Add Question'**
  String get addQuestion;

  /// No description provided for @questionText.
  ///
  /// In en, this message translates to:
  /// **'Question text'**
  String get questionText;

  /// No description provided for @answers.
  ///
  /// In en, this message translates to:
  /// **'Answers'**
  String get answers;

  /// No description provided for @selectNumberOfQuestions.
  ///
  /// In en, this message translates to:
  /// **'Select Number of Questions'**
  String get selectNumberOfQuestions;

  /// No description provided for @estimatedTime.
  ///
  /// In en, this message translates to:
  /// **'Est. Time'**
  String get estimatedTime;

  /// No description provided for @startExam.
  ///
  /// In en, this message translates to:
  /// **'Start Exam'**
  String get startExam;

  /// No description provided for @examComplete.
  ///
  /// In en, this message translates to:
  /// **'Exam Complete!'**
  String get examComplete;

  /// No description provided for @congratulationsPassed.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! You passed!'**
  String get congratulationsPassed;

  /// No description provided for @keepPracticing.
  ///
  /// In en, this message translates to:
  /// **'Keep practicing!'**
  String get keepPracticing;

  /// No description provided for @correct.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correct;

  /// No description provided for @correctAnswers.
  ///
  /// In en, this message translates to:
  /// **'Correct'**
  String get correctAnswers;

  /// No description provided for @incorrectAnswers.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrectAnswers;

  /// No description provided for @timeTaken.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get timeTaken;

  /// No description provided for @submittingResults.
  ///
  /// In en, this message translates to:
  /// **'Submitting results...'**
  String get submittingResults;

  /// No description provided for @resultsSaved.
  ///
  /// In en, this message translates to:
  /// **'Results saved!'**
  String get resultsSaved;

  /// No description provided for @backToExams.
  ///
  /// In en, this message translates to:
  /// **'Back to Exams'**
  String get backToExams;

  /// No description provided for @previous.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @addExamByCode.
  ///
  /// In en, this message translates to:
  /// **'Add Exam by Code'**
  String get addExamByCode;

  /// No description provided for @examAddedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Exam added successfully'**
  String get examAddedSuccessfully;

  /// No description provided for @noSharedExams.
  ///
  /// In en, this message translates to:
  /// **'No shared exams yet'**
  String get noSharedExams;

  /// No description provided for @removeSharedExam.
  ///
  /// In en, this message translates to:
  /// **'Remove Shared Exam'**
  String get removeSharedExam;

  /// No description provided for @removeSharedExamConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this shared exam from your library?'**
  String get removeSharedExamConfirm;

  /// Message shown when an exam contains no questions
  ///
  /// In en, this message translates to:
  /// **'This exam has no questions.'**
  String get examHasNoQuestions;

  /// No description provided for @selectConversation.
  ///
  /// In en, this message translates to:
  /// **'Select a conversation'**
  String get selectConversation;

  /// No description provided for @orCreateNew.
  ///
  /// In en, this message translates to:
  /// **'or create a new one from the sidebar'**
  String get orCreateNew;

  /// No description provided for @startChatting.
  ///
  /// In en, this message translates to:
  /// **'Start chatting'**
  String get startChatting;

  /// No description provided for @askAnything.
  ///
  /// In en, this message translates to:
  /// **'Ask me anything!'**
  String get askAnything;

  /// No description provided for @tools.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// No description provided for @selectTools.
  ///
  /// In en, this message translates to:
  /// **'Select Tools'**
  String get selectTools;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get clearAll;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Learning Dashboard'**
  String get dashboardTitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Track your progress and achievements'**
  String get dashboardSubtitle;

  /// No description provided for @studyStreak.
  ///
  /// In en, this message translates to:
  /// **'Study Streak'**
  String get studyStreak;

  /// No description provided for @totalStudyTime.
  ///
  /// In en, this message translates to:
  /// **'Study Time'**
  String get totalStudyTime;

  /// No description provided for @averageExamScore.
  ///
  /// In en, this message translates to:
  /// **'Avg Score'**
  String get averageExamScore;

  /// No description provided for @flashcardsStudied.
  ///
  /// In en, this message translates to:
  /// **'Cards Studied'**
  String get flashcardsStudied;

  /// No description provided for @totalCards.
  ///
  /// In en, this message translates to:
  /// **'total'**
  String get totalCards;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'this month'**
  String get thisMonth;

  /// No description provided for @allExams.
  ///
  /// In en, this message translates to:
  /// **'all exams'**
  String get allExams;

  /// No description provided for @keepItUp.
  ///
  /// In en, this message translates to:
  /// **'Keep it up!'**
  String get keepItUp;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity yet'**
  String get noRecentActivity;

  /// No description provided for @flashcardDifficultyDistribution.
  ///
  /// In en, this message translates to:
  /// **'Flashcard Performance'**
  String get flashcardDifficultyDistribution;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your learning starts and ends here'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Combine exams, flashcards, and intelligent chat in one place.'**
  String get welcomeSubtitle;

  /// No description provided for @chatTabTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Chat'**
  String get chatTabTitle;

  /// No description provided for @chatDescription.
  ///
  /// In en, this message translates to:
  /// **'Talk to your AI assistant'**
  String get chatDescription;

  /// No description provided for @flashcardsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Flashcards'**
  String get flashcardsTabTitle;

  /// No description provided for @testsTabTitle.
  ///
  /// In en, this message translates to:
  /// **'Tests'**
  String get testsTabTitle;

  /// No description provided for @loginToAccess.
  ///
  /// In en, this message translates to:
  /// **'Log in to access your dashboard'**
  String get loginToAccess;

  /// No description provided for @loginToAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'Track your progress, study streak, and more'**
  String get loginToAccessDescription;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @learningCalendar.
  ///
  /// In en, this message translates to:
  /// **'Learning Calendar'**
  String get learningCalendar;

  /// No description provided for @daysStudied.
  ///
  /// In en, this message translates to:
  /// **'days studied'**
  String get daysStudied;

  /// No description provided for @flashcardsStudiedLabel.
  ///
  /// In en, this message translates to:
  /// **'Flashcards studied'**
  String get flashcardsStudiedLabel;

  /// No description provided for @scheduledReviews.
  ///
  /// In en, this message translates to:
  /// **'Scheduled reviews'**
  String get scheduledReviews;

  /// No description provided for @noActivityThisDay.
  ///
  /// In en, this message translates to:
  /// **'No activity this day'**
  String get noActivityThisDay;

  /// No description provided for @noScheduledReviews.
  ///
  /// In en, this message translates to:
  /// **'No scheduled reviews'**
  String get noScheduledReviews;

  /// No description provided for @less.
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get less;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @scheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get scheduled;

  /// No description provided for @errorLoadingData.
  ///
  /// In en, this message translates to:
  /// **'Error loading data'**
  String get errorLoadingData;

  /// No description provided for @incorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect'**
  String get incorrect;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'pl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'pl':
      return AppLocalizationsPl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
