/// The two languages SFMS ships in.
enum AppLang { so, en }

/// App text in Somali and English.
///
/// A deliberately lightweight layer (not Flutter's gen_l10n): Somali (`so`)
/// isn't in Flutter's built-in localization set, and a plain getter-per-string
/// class lets translation happen screen-by-screen and switch live through
/// Riverpod. Each getter reads `_(english, somali)` — add getters as screens
/// are localized. Somali here is a first pass; a native speaker should refine.
class AppStrings {
  const AppStrings(this.lang);
  final AppLang lang;

  bool get isSo => lang == AppLang.so;
  String _(String en, String so) => isSo ? so : en;

  // --- Bottom navigation ---
  String get navHome => _('Home', 'Guriga');
  String get navFarms => _('Farms', 'Beeraha');
  String get navAiDoctor => _('AI Doctor', 'Dhakhtar AI');
  String get navCommunity => _('Community', 'Bulshada');
  String get navProfile => _('Profile', 'Akoonka');

  // --- Common actions ---
  String get save => _('Save', 'Kaydi');
  String get saveChanges => _('Save changes', 'Kaydi isbeddellada');
  String get cancel => _('Cancel', 'Jooji');
  String get delete => _('Delete', 'Tirtir');
  String get edit => _('Edit', 'Wax ka beddel');
  String get add => _('Add', 'Ku dar');
  String get retry => _('Retry', 'Isku day mar kale');

  // --- Dashboard ---
  String get welcomeBack => _('Welcome back,', 'Ku soo dhawoow,');
  String get quickActions => _('Quick Actions', "Ficillo Degdeg ah");
  String get activeCrops => _('Active Crops', 'Dalagyada Firfircoon');
  String get recentActivity => _('Recent Activity', 'Dhaqdhaqaaqa Dhawaan');
  String get viewAll => _('View all', 'Dhammaan fiiri');
  String get netProfit => _('NET PROFIT', 'FAA’IIDO SAAFI AH');
  String get totalRevenue => _('Total Revenue', 'Wadarta Dakhliga');
  String get totalExpenses => _('Total Expenses', 'Wadarta Kharashka');
  String get noCropsYet => _('No active crops yet', 'Weli dalag firfircoon ma jiro');

  // --- Quick action tiles ---
  String get addExpense => _('Add Expense', 'Ku dar Kharash');
  String get addHarvest => _('Add Harvest', 'Ku dar Goosasho');
  String get recordSale => _('Record Sale', 'Diiwaangeli Iib');
  String get tasks => _('Tasks', 'Hawlaha');
  String get workers => _('Workers', 'Shaqaalaha');
  String get equipment => _('Equipment', 'Qalabka');
  String get water => _('Water', 'Biyaha');
  String get weather => _('Weather', 'Cimilada');
  String get nursery => _('Nursery', 'Fadhiga Dhirta');
  String get livestock => _('Livestock', 'Xoolaha');
  String get pests => _('Pests', 'Cayayaanka');
  String get farmMap => _('Farm Map', 'Khariidada Beerta');
  String get inventory => _('Inventory', 'Kaydka');
  String get records => _('Records', 'Diiwaannada');
  String get reports => _('Reports', 'Warbixinno');
  String get aiPlantDoctor => _('AI Plant Doctor', 'Dhakhtar Dhir AI');
  String get aiAssistant => _('AI Assistant', 'Kaaliye AI');
  String get aiInsights => _('AI Insights', 'Aragtiyo AI');
  String get aiAnalytics => _('AI Analytics', 'Falanqayn AI');
  String get knowledge => _('Knowledge', 'Aqoonta');

  // --- Profile ---
  String get profile => _('Profile', 'Akoonka');
  String get signOut => _('Sign out', 'Ka bax');
  String get settingsPrefs =>
      _('Settings & Preferences', 'Dejinta & Doorbidyada');
  String get farmSettings => _('Farm Settings', 'Dejinta Beerta');
  String get financialReports =>
      _('Financial Reports', 'Warbixinada Maaliyadda');
  String get language => _('Language', 'Luqadda');
  String get helpSupport => _('Help & Support', 'Caawimo & Taageero');
  String get editProfile => _('Edit profile', 'Wax ka beddel Akoonka');
  String get activeFarms => _('Active Farms', 'Beero Firfircoon');
  String get fullName => _('Full name', 'Magaca oo dhan');
  String get phoneOptional => _('Phone (optional)', 'Telefoon (ikhtiyaari)');
  String get nameRequired =>
      _('A name is required.', 'Magaca waa lagama maarmaan.');
  String get farmSettingsSub =>
      _('Add, edit or remove your farms', 'Ku dar, wax ka beddel ama tirtir beeraha');
  String get financialReportsSub =>
      _('Revenue, expenses and profit', 'Dakhliga, kharashka iyo faa’iidada');
  String get helpSupportSub => _('How the app works, and how to reach us',
      'Sida app-ku u shaqeeyo, iyo sida nagala soo xiriirto');

  // --- Auth ---
  String get email => _('Email', 'Iimayl');
  String get password => _('Password', 'Furaha sirta ah');
  String get signIn => _('Sign in', 'Gal');
  String get authWelcome => _('Welcome back', 'Ku soo dhawoow');
  String get signInSubtitle =>
      _('Sign in to your farm dashboard.', 'Gal dashboard-ka beertaada.');
  String get newToSfms => _('New to Somali Farm?  ', 'Cusub Somali Farm?  ');
  String get createAccount => _('Create an account', 'Samee akoon');
  String get forgotPassword => _('Forgot password?', 'Ma iloowday furaha?');
  String get somethingWrong => _('Something went wrong. Please try again.',
      'Wax baa qaldamay. Fadlan isku day mar kale.');
  String get checkYourEmail => _('Check your email', 'Hubi iimaylkaaga');
  String get backToSignIn => _('Back to sign in', 'Ku noqo galitaanka');
  String get createAccountTitle => _('Create account', 'Samee akoon');
  String get registerSubtitle => _('Start managing your farm digitally.',
      'Bilow inaad beertaada si dijital ah u maamusho.');
  String get alreadyHaveAccount =>
      _('Already have an account?  ', 'Horey ma u leedahay akoon?  ');
  String get passwordMinHint => _('At least 6 characters', 'Ugu yaraan 6 xaraf');
  String get passwordMinError => _('Password must be at least 6 characters.',
      'Furaha waa inuu ahaadaa ugu yaraan 6 xaraf.');
  String get resetPassword => _('Reset password', 'Dib u deji furaha');
  String get resetSubtitle => _(
      "Enter your email and we'll send you a reset link.",
      'Geli iimaylkaaga waxaana kuu soo diri doonnaa link dib-u-dejin.');
  String get sendResetLink =>
      _('Send reset link', 'Dir link-ga dib-u-dejinta');

  String confirmSentTo(String email) => _(
      'We sent a confirmation link to $email. Click it to activate your '
          'account, then sign in.',
      'Link xaqiijin ah ayaan u dirnay $email. Guji si aad akoonkaaga u '
          'firfircooniso, ka dibna gal.');
  String resetSentTo(String email) => _(
      'If an account exists for $email, a reset link is on its way.',
      'Haddii akoon u jiro $email, link dib-u-dejin ayaa soo socda.');

  // --- Records ---
  String get tabExpenses => _('Expenses', 'Kharashyada');
  String get tabHarvests => _('Harvests', 'Goosashada');
  String get tabSales => _('Sales', 'Iibka');
  String get createFarmToSeeRecords => _('Create a farm to see records.',
      'Samee beero si aad u aragto diiwaannada.');
  String get noExpenses => _('No expenses logged yet.',
      'Weli kharash lama diiwaangelin.');
  String get noHarvests => _('No harvests recorded yet.',
      'Weli goosasho lama diiwaangelin.');
  String get noSales =>
      _('No sales recorded yet.', 'Weli iib lama diiwaangelin.');
  String get grade => _('Grade', 'Darajo');
  String get deleteRecordQ => _('Delete record?', 'Diiwaanka ma tirtiraysaa?');
  String get deleteRecordBody => _('This will be permanently removed.',
      'Tan ayaa si joogto ah loo tirtiri doonaa.');
  String get couldNotDelete => _('Could not delete.', 'Lama tirtiri karo.');
  String get couldNotLoadRecords =>
      _('Could not load records.', 'Diiwaannada lama soo dejin karo.');

  // --- Form field labels (shared by the add/edit forms) ---
  String get amount => _('Amount', 'Qadarka');
  String get farm => _('Farm', 'Beerta');
  String get category => _('Category', 'Qaybta');
  String get date => _('Date', 'Taariikhda');
  String get paymentMethod => _('Payment method', 'Habka lacag-bixinta');
  String get paymentStatus => _('Payment status', 'Xaaladda lacag-bixinta');
  String get supplier => _('Supplier', 'Alaab-qeybiye');
  String get plot => _('Plot', 'Goobta');
  String get crop => _('Crop', 'Dalagga');
  String get notes => _('Notes', 'Faallooyin');
  String get quantity => _('Quantity', 'Tirada');
  String get unit => _('Unit', 'Halbeeg');
  String get unitPrice => _('Unit price', 'Qiimaha halbeegga');
  String get discount => _('Discount', 'Dhimis');
  String get customer => _('Customer', 'Macmiil');
  String get market => _('Market', 'Suuqa');
  String get receiptPhoto => _('Receipt photo', 'Sawirka rasiidka');
  String get optional => _('Optional', 'Ikhtiyaari');
  String get selectCategory => _('Select a category', 'Dooro qayb');
  String get whoYouPaid =>
      _('Who you paid (optional)', 'Cidda aad bixisay (ikhtiyaari)');
  String get extraDetail =>
      _('Any extra detail (optional)', 'Faahfaahin dheeraad ah (ikhtiyaari)');
  String get noCropsOptional =>
      _('No crops yet (optional)', 'Weli dalag ma jiro (ikhtiyaari)');
  String get selectCrop => _('Select a crop', 'Dooro dalag');
  String get couldNotLoadFarms =>
      _('Could not load your farms.', 'Beerahaaga lama soo dejin karo.');
  String get buyerName =>
      _('Buyer name (optional)', 'Magaca iibsadaha (ikhtiyaari)');
  String get whereSold =>
      _('Where it was sold (optional)', 'Meesha lagu iibiyay (ikhtiyaari)');
  String get takePhoto => _('Take a photo', 'Sawir qaad');
  String get chooseGallery => _('Choose from gallery', 'Ka dooro albumka');
  String get replaceReceipt => _('Replace receipt', 'Bedel rasiidka');
  String get addReceipt => _('Add a receipt', 'Ku dar rasiid');
  String get couldNotLoadCategories =>
      _('Could not load categories.', 'Qaybaha lama soo dejin karo.');

  // --- Expense / Harvest / Sale forms ---
  String get editExpense => _('Edit Expense', 'Wax ka beddel Kharashka');
  String get saveExpense => _('Save expense', 'Kaydi kharashka');
  String get expenseSaved => _('Expense saved', 'Kharashka waa la kaydiyay');
  String get expenseUpdated =>
      _('Expense updated', 'Kharashka waa la cusboonaysiiyay');
  String get editHarvest => _('Edit Harvest', 'Wax ka beddel Goosashada');
  String get saveHarvest => _('Save harvest', 'Kaydi goosashada');
  String get harvestSaved => _('Harvest saved', 'Goosashada waa la kaydiyay');
  String get harvestUpdated =>
      _('Harvest updated', 'Goosashada waa la cusboonaysiiyay');
  String get editSale => _('Edit Sale', 'Wax ka beddel Iibka');
  String get saveSale => _('Save sale', 'Kaydi iibka');
  String get saleTotal => _('SALE TOTAL', 'WADARTA IIBKA');
  String get saleRecorded => _('Sale recorded', 'Iibka waa la diiwaangeliyay');
  String get saleUpdated => _('Sale updated', 'Iibka waa la cusboonaysiiyay');

  // --- Module screen chrome (app bar titles + FAB labels) ---
  String get pestsTitle => _('Pests & Diseases', 'Cayayaanka & Cudurada');
  String get newTask => _('New task', 'Hawl cusub');
  String get addWorker => _('Add worker', 'Ku dar shaqaale');
  String get addEquipment => _('Add equipment', 'Ku dar qalab');
  String get logWatering => _('Log watering', 'Diiwaangeli waraabin');
  String get newBatch => _('New batch', 'Dufcad cusub');
  String get addAnimals => _('Add animals', 'Ku dar xoolo');
  String get report => _('Report', 'Soo sheeg');
  String get addItem => _('Add item', 'Ku dar shay');
  String get exportPdf => _('Export PDF', 'Soo saar PDF');
  String get exportExcel => _('Export Excel', 'Soo saar Excel');
  String get newPost => _('New post', 'Qoraal cusub');
  String get myFarms => _('My Farms', 'Beerahayga');
  String get addFarm => _('Add farm', 'Ku dar beer');
  String get knowledgeBase => _('Knowledge Base', 'Kaydka Aqoonta');

  // --- AI Plant Doctor result ---
  String get aiConfidence => _('AI confidence', 'Kalsoonida AI');
  String get highConfidence => _('High confidence in this diagnosis.',
      'Kalsooni sare ayaa loo hayaa baaritaankan.');
  String get uncertainDiagnosis => _(
      'Uncertain — treat as a likely, not confirmed, diagnosis.',
      'Ma hubna — u qaado mid u badan, oo aan la xaqiijin.');
  String get symptomsDetected => _('Symptoms detected', 'Astaamaha la ogaaday');
  String get causeLabel => _('Cause', 'Sababta');
  String get environmentalPrefix => _('Environmental: ', 'Deegaanka: ');
  String get recommendedActionsLabel =>
      _('Recommended actions', 'Talooyinka la qaadayo');
  String get medicineOptionsTitle =>
      _('Medicine options', 'Doorashooyinka dawada');
  String get chooseOneHint => _(
      'Pick one based on what your local shop stocks.',
      'Dooro mid ku salaysan waxa dukaankaaga deegaanka laga helo.');
  String get option => _('Option', 'Doorasho');
  String get organicTreatmentLabel =>
      _('Organic treatment', 'Daawaynta dabiiciga ah');
  String get safetyLabel => _('Safety', 'Badbaadada');
  String get wearPrefix => _('Wear: ', 'Xidho: ');
  String get preventionLabel => _('Prevention', 'Kahortagga');
  String get recoveryTimingLabel =>
      _('Recovery & timing', 'Bogsashada & waqtiga');
  String get expectedRecoveryLabel =>
      _('Expected recovery', 'Bogsasho la filayo');
  String get diseaseTimelineLabel => _('Disease timeline', 'Jadwalka cudurka');
  String get recoveryStatusLabel =>
      _('Recovery status', 'Xaaladda bogsashada');
  String get alsoConsiderPrefix => _('Also consider: ', 'Sidoo kale tixgeli: ');
  String get possibleIssue => _('Possible issue', 'Arrin suurtagal ah');
  String get expertBannerText => _(
      'This is a likely diagnosis, not a certainty. Confirm with an '
          'agricultural expert before major treatment.',
      'Kani waa baaris u badan, ma aha mid hubaal ah. La xaqiiji khabiir '
          'beeraha ka hor daawayn weyn.');
  String get mixPerSprayer => _('Mix per sprayer', 'Isku dar kiish kasta');
  String doseLine(String dose) =>
      _('Dose: $dose per litre of water', 'Qiyaasta: $dose litir kasta oo biyo ah');
  String get mixingRatioLabel => _('Mixing ratio', 'Saamiga isku-darka');
  String get repeatLabel => _('Repeat', 'Ku celi');
  String get maxApplicationsLabel => _('Max applications', 'Tirada ugu badan');
  String get preHarvestLabel =>
      _('Pre-harvest interval', 'Muddada goosashada ka hor');
  String get couldNotUpdateStatus =>
      _('Could not update status.', 'Xaaladda lama cusboonaysiin karo.');
  // Health / timeline / recovery tokens
  String get healthyLabel => _('Healthy', 'Caafimaad qaba');
  String get diseasedLabel => _('Diseased', 'Cudur qaba');
  String get unclearLabel => _('Unclear', 'Aan cadayn');
  String get stageDetected => _('Detected', 'La ogaaday');
  String get stageTreatment => _('Treatment', 'Daawayn');
  String get stageRecovering => _('Recovering', 'Bogsanaya');
  String get stageRecovered => _('Recovered', 'Bogsaday');
  String get recNotStarted => _('Not started', 'Lama bilaabin');
  String get recLost => _('Lost', 'Lumay');
}
