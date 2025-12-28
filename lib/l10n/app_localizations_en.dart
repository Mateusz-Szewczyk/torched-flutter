// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get menu => 'Menu';

  @override
  String get flashcards => 'Flashcards';

  @override
  String get flashcardsDescription =>
      'Create and study flashcard decks to boost your learning';

  @override
  String get chat => 'Chat';

  @override
  String get login_register => 'Login / Register';

  @override
  String get settings => 'Settings';

  @override
  String get hide_panel => 'Hide panel';

  @override
  String get show_panel => 'Show panel';

  @override
  String get settings_saved_successfully => 'Settings saved successfully.';

  @override
  String get language => 'Select language';

  @override
  String get dark_mode => 'Dark mode';

  @override
  String get dark_mode_description => 'Enable or disable dark mode';

  @override
  String get save_changes => 'Save changes';

  @override
  String get english => 'English';

  @override
  String get polish => 'Polish';

  @override
  String get spanish => 'Spanish';

  @override
  String get french => 'French';

  @override
  String get german => 'German';

  @override
  String get manage_files => 'Manage files';

  @override
  String get manage_uploaded_files => 'Manage uploaded files';

  @override
  String get file_description => 'File description';

  @override
  String get enter_file_description => 'Enter file description';

  @override
  String get category => 'Category';

  @override
  String get enter_category => 'Enter category';

  @override
  String get start_page => 'Start page';

  @override
  String get end_page => 'End page';

  @override
  String get optional => 'Optional';

  @override
  String get uploaded_files => 'Uploaded files';

  @override
  String get no_files_uploaded_yet => 'No files uploaded yet.';

  @override
  String get uploading => 'Uploading...';

  @override
  String get upload_new_file => 'Upload new file';

  @override
  String get error_file_description_required => 'File description is required.';

  @override
  String get error_category_required => 'Category is required.';

  @override
  String get error_fetch_files =>
      'An error occurred while fetching uploaded files.';

  @override
  String get loading_decks => 'Loading decks...';

  @override
  String get error => 'Error';

  @override
  String get errorOccurred => 'An error occurred';

  @override
  String get try_again => 'Try again';

  @override
  String get welcome_flashcards => 'Welcome to Flashcards!';

  @override
  String get get_started_create_deck =>
      'Get started by creating your first deck.';

  @override
  String get no_flashcard_decks =>
      'You don\'t have any flashcard decks yet. Create a new deck to start learning!';

  @override
  String get create_your_first_deck => 'Create your first deck';

  @override
  String get createDeck => 'Create Deck';

  @override
  String get create_new_deck => 'Create new deck';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get study => 'Study';

  @override
  String get flashcards_tooltip =>
      'Need flashcards? Chat can help you create study-ready flashcards in seconds.';

  @override
  String get more_information => 'More information';

  @override
  String get no_flashcards_available => 'No flashcards available';

  @override
  String get deck_has_no_flashcards =>
      'This deck doesn\'t contain any flashcards yet.';

  @override
  String get back_to_decks => 'Back to decks';

  @override
  String get congratulations => 'Congratulations!';

  @override
  String get completed_flashcards =>
      'You\'ve completed all flashcards in this deck.';

  @override
  String get reset_deck => 'Reset deck';

  @override
  String get exit_study => 'Exit study';

  @override
  String card_counter(Object current, Object total) {
    return 'Card $current of $total';
  }

  @override
  String get type_message => 'Type your message...';

  @override
  String get writing_response => 'Writing response...';

  @override
  String get send => 'Send';

  @override
  String get new_conversation => 'New conversation';

  @override
  String get edit_title => 'Edit title';

  @override
  String get new_title => 'New title';

  @override
  String get delete_conversation => 'Delete conversation';

  @override
  String get confirm_delete_title => 'Confirm deletion';

  @override
  String get confirm_delete_description =>
      'Are you sure you want to delete this conversation? This action cannot be undone.';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get add_flashcard => 'Add flashcard';

  @override
  String get edit_deck => 'Edit deck';

  @override
  String get editDeck => 'Edit Deck';

  @override
  String get deck_name => 'Deck name';

  @override
  String get deckName => 'Deck Name';

  @override
  String get enter_deck_name => 'Enter deck name';

  @override
  String get deck_description => 'Deck description';

  @override
  String get enter_deck_description => 'Enter deck description';

  @override
  String flashcard_number(Object number) {
    return 'Flashcard number $number';
  }

  @override
  String get question => 'Question';

  @override
  String get enter_question => 'Enter question';

  @override
  String get answer => 'Answer';

  @override
  String get enter_answer => 'Enter answer';

  @override
  String get modern_homepage_title => 'Where your learning begins and ends';

  @override
  String get modern_homepage_subtitle =>
      'Connect the world of exams, flashcards and intelligent chat in one place.';

  @override
  String get email => 'Email';

  @override
  String get email_placeholder => 'm@example.com';

  @override
  String get password => 'Password';

  @override
  String get confirm_password => 'Confirm password';

  @override
  String get login => 'Login';

  @override
  String get register => 'Register';

  @override
  String get logout => 'Logout';

  @override
  String get tests => 'Tests';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get profile => 'Profile';

  @override
  String get searchDecks => 'Search decks...';

  @override
  String get cards => 'cards';

  @override
  String get shared => 'Shared';

  @override
  String get share => 'Share';

  @override
  String get addByCode => 'Add by Code';

  @override
  String get manageShares => 'Manage Shares';

  @override
  String get name => 'Name';

  @override
  String get cardCount => 'Card Count';

  @override
  String get recent => 'Recent';

  @override
  String get lastSession => 'Last Session';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get deleteDeck => 'Delete Deck';

  @override
  String deleteDeckConfirm(String name) {
    return 'Are you sure you want to delete \"$name\"? This cannot be undone.';
  }

  @override
  String get deckDeleted => 'Deck deleted';

  @override
  String get removeSharedDeck => 'Remove Shared Deck';

  @override
  String get removeSharedDeckConfirm =>
      'Are you sure you want to remove this shared deck from your library?';

  @override
  String get remove => 'Remove';

  @override
  String get removeFromLibrary => 'Remove from library';

  @override
  String get showAnswer => 'Show Answer';

  @override
  String get tapToFlip => 'Tap to flip';

  @override
  String get hard => 'Hard';

  @override
  String get tryAgain => 'Try again';

  @override
  String get good => 'Good';

  @override
  String get reviewLater => 'Review later';

  @override
  String get easy => 'Easy';

  @override
  String get gotIt => 'Got it!';

  @override
  String get exit => 'Exit';

  @override
  String get sessionComplete => 'Session Complete!';

  @override
  String cardsReviewed(String count) {
    return 'You reviewed $count cards';
  }

  @override
  String nextSession(String date) {
    return 'Next session: $date';
  }

  @override
  String get retakeHardCards => 'Retake Hard Cards';

  @override
  String get retakeSession => 'Retake Session';

  @override
  String get saveAndExit => 'Save & Exit';

  @override
  String get backToDecks => 'Back to Decks';

  @override
  String get noCardsToRetake => 'No cards to retake';

  @override
  String get finish => 'Finish';

  @override
  String get noHardCardsFound => 'No hard cards found';

  @override
  String get addDeckByCode => 'Add Deck by Code';

  @override
  String get shareCode => 'Share Code';

  @override
  String get alreadyAdded => 'Already in your library';

  @override
  String get add => 'Add';

  @override
  String get deckAddedSuccessfully => 'Deck added successfully';

  @override
  String get noSharedDecks => 'No shared decks yet';

  @override
  String get close => 'Close';

  @override
  String get description => 'Description (optional)';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get addCard => 'Add Card';

  @override
  String get card => 'Card';

  @override
  String get testsDescription =>
      'Create and take practice exams to test your knowledge';

  @override
  String get searchExams => 'Search exams...';

  @override
  String get welcomeTests => 'Welcome to Tests';

  @override
  String get getStartedCreateTest =>
      'Create your first exam or add one using a share code';

  @override
  String get createExam => 'Create Exam';

  @override
  String get editExam => 'Edit Exam';

  @override
  String get deleteExam => 'Delete Exam';

  @override
  String get examDeleted => 'Exam deleted';

  @override
  String get examName => 'Exam Name';

  @override
  String get questions => 'Questions';

  @override
  String get addQuestion => 'Add Question';

  @override
  String get questionText => 'Question text';

  @override
  String get answers => 'Answers';

  @override
  String get selectNumberOfQuestions => 'Select Number of Questions';

  @override
  String get estimatedTime => 'Est. Time';

  @override
  String get startExam => 'Start Exam';

  @override
  String get examComplete => 'Exam Complete!';

  @override
  String get congratulationsPassed => 'Congratulations! You passed!';

  @override
  String get keepPracticing => 'Keep practicing!';

  @override
  String get correct => 'Correct';

  @override
  String get correctAnswers => 'Correct';

  @override
  String get incorrectAnswers => 'Incorrect';

  @override
  String get timeTaken => 'Time';

  @override
  String get submittingResults => 'Submitting results...';

  @override
  String get resultsSaved => 'Results saved!';

  @override
  String get backToExams => 'Back to Exams';

  @override
  String get previous => 'Previous';

  @override
  String get next => 'Next';

  @override
  String get addExamByCode => 'Add Exam by Code';

  @override
  String get examAddedSuccessfully => 'Exam added successfully';

  @override
  String get noSharedExams => 'No shared exams yet';

  @override
  String get removeSharedExam => 'Remove Shared Exam';

  @override
  String get removeSharedExamConfirm =>
      'Are you sure you want to remove this shared exam from your library?';

  @override
  String get examHasNoQuestions => 'This exam has no questions.';

  @override
  String get selectConversation => 'Select a conversation';

  @override
  String get orCreateNew => 'or create a new one from the sidebar';

  @override
  String get startChatting => 'Start chatting';

  @override
  String get askAnything => 'Ask me anything!';

  @override
  String get tools => 'Tools';

  @override
  String get selectTools => 'Select Tools';

  @override
  String get clearAll => 'Clear All';

  @override
  String get done => 'Done';

  @override
  String get dashboardTitle => 'Your Learning Dashboard';

  @override
  String get dashboardSubtitle => 'Track your progress and achievements';

  @override
  String get studyStreak => 'Study Streak';

  @override
  String get totalStudyTime => 'Study Time';

  @override
  String get averageExamScore => 'Avg Score';

  @override
  String get flashcardsStudied => 'Cards Studied';

  @override
  String get totalCards => 'total';

  @override
  String get thisMonth => 'this month';

  @override
  String get allExams => 'all exams';

  @override
  String get keepItUp => 'Keep it up!';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get viewAll => 'View All';

  @override
  String get noRecentActivity => 'No recent activity yet';

  @override
  String get flashcardDifficultyDistribution => 'Flashcard Performance';

  @override
  String get welcomeTitle => 'Your learning starts and ends here';

  @override
  String get welcomeSubtitle =>
      'Combine exams, flashcards, and intelligent chat in one place.';

  @override
  String get chatTabTitle => 'AI Chat';

  @override
  String get chatDescription => 'Talk to your AI assistant';

  @override
  String get flashcardsTabTitle => 'Flashcards';

  @override
  String get testsTabTitle => 'Tests';

  @override
  String get loginToAccess => 'Log in to access your dashboard';

  @override
  String get loginToAccessDescription =>
      'Track your progress, study streak, and more';

  @override
  String get retry => 'Retry';

  @override
  String get learningCalendar => 'Learning Calendar';

  @override
  String get daysStudied => 'days studied';

  @override
  String get flashcardsStudiedLabel => 'Flashcards studied';

  @override
  String get scheduledReviews => 'Scheduled reviews';

  @override
  String get noActivityThisDay => 'No activity this day';

  @override
  String get noScheduledReviews => 'No scheduled reviews';

  @override
  String get less => 'Less';

  @override
  String get more => 'More';

  @override
  String get scheduled => 'Scheduled';

  @override
  String get errorLoadingData => 'Error loading data';
}
