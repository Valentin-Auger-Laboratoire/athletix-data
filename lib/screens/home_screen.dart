// home_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:athletix_data/services/api.dart';
import 'landing_screen.dart';
import 'login_screen.dart';
import 'selection_screen.dart';
import 'questionnaire_screen.dart';
import 'classement_screen.dart';
import 'ia_result_screen.dart';
import 'brassard_screen.dart';
import 'historique_screen.dart';
import 'evolution_screen.dart';
import 'reglages_screen.dart';
import 'compte_screen.dart';
import 'package:athletix_data/widgets/carte_semaine.dart';
import 'consentement.dart';
import 'package:athletix_data/services/brassard/brassard_actif.dart';
import 'package:athletix_data/services/brassard/source_brassard.dart';
import 'package:athletix_data/services/telephone/batterie_ble.dart';
import 'package:athletix_data/services/telephone/cardio.dart';
import 'package:athletix_data/services/telephone/montre_podometre.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final String userName = Api.session?.pseudo ?? "Athlète";
  String aiMessage = "Remplis ton profil pour obtenir des conseils personnalisés.";
  int? batteryLevel; // null = inconnu (aucune donnée du brassard)
  bool isConnected = false;
  Map<String, dynamic>? _profilExistant; // ✅ stocke le profil chargé
  List<Map<String, dynamic>> _historiqueProfils = [];

  @override
  void initState() {
    super.initState();
    _fetchHardwareStatus();
    _loadProfilIA(); // ✅ charge le profil au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) => _verifierConsentement());
  }

  // Données de santé : accord demandé une fois, au premier lancement (RGPD)
  Future<void> _verifierConsentement() async {
    final accord = await Consentement.demanderSiBesoin(context, demo: Api.isDemo);
    if (accord || !mounted) return;
    final wasDemo = Api.isDemo;
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => wasDemo ? const LandingScreen() : const LoginScreen()),
      (route) => false,
    );
  }

  void _ouvrirBrassard() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const BrassardScreen()));

  /// Mode d'emploi (2 pages, PDF publié avec le dépôt : mode-emploi/mode-emploi.pdf).
  static final Uri modeEmploi = Uri.parse(
      'https://github.com/Valentin-Auger-Laboratoire/athletix-data/blob/main/mode-emploi/mode-emploi.pdf');

  Future<void> _ouvrirModeEmploi() async {
    final messenger = ScaffoldMessenger.of(context);
    var ouvert = false;
    try {
      ouvert = await launchUrl(modeEmploi, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ouvert) {
      messenger.showSnackBar(const SnackBar(
        content: Text("Impossible d'ouvrir le mode d'emploi (pas de réseau ?). Il est aussi dans le dépôt GitHub, dossier mode-emploi."),
      ));
    }
  }

  void _ouvrirHistorique() =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoriqueScreen()));

  // ✅ Lecture seule : l'ouverture de l'accueil ne modifie plus l'état du brassard
  Future<void> _fetchHardwareStatus() async {
    final data = await Api.current.getHardware();
    if (data['status'] == 'success' && mounted) {
      setState(() {
        isConnected = data['connected'] == true;
        batteryLevel = data['battery'] is int ? data['battery'] : null;
      });
    }
  }

  // ✅ Charge le profil IA depuis la BDD (ou la démo)
  Future<void> _loadProfilIA() async {
    final data = await Api.current.getProfil();
    if (data['status'] == 'success' && mounted) {
      setState(() {
        _profilExistant = Map<String, dynamic>.from(data['profil']);
        _historiqueProfils = List<Map<String, dynamic>>.from(data['historique'] ?? []);
        aiMessage = "Profil chargé ! Appuie pour voir tes conseils personnalisés.";
      });
    }
  }

  // La description de chaque catégorie est construite à partir de sa liste de sports :
  // elle ne peut plus oublier un sport. 'mesure' = ce que le brassard EMG affiche pendant la séance.
  final List<Map<String, dynamic>> categories = [
    {'name': 'Endurance & Cardio', 'icon': Icons.directions_run, 'color': Colors.blue, 'subCategories': ['Running', 'Trail', 'Cyclisme', 'VTT', 'Ski', 'Aviron'], 'mesure': 'ACTIVITE_MOYENNE',},
    {'name': 'Force & Intensité', 'icon': Icons.fitness_center, 'color': Colors.red, 'subCategories': ['Musculation', 'Crossfit', 'Haltérophilie', 'HIIT', 'Fitness'], 'mesure': 'PIC_CONTRACTION',},
    {'name': 'Duel & Collectif', 'icon': Icons.sports_tennis, 'color': Colors.green, 'subCategories': ['Football', 'Tennis', 'Basketball', 'Handball', 'Boxe'], 'mesure': 'EFFORTS_INTENSES',},
    {'name': 'Milieu Aquatique', 'icon': Icons.pool, 'color': Colors.cyan, 'subCategories': ['Natation', 'Aquabike', 'Water-polo', 'Paddle', 'Surf', 'Apnée'], 'mesure': 'HORS_LIGNE',},
    {'name': 'Zen & Posture', 'icon': Icons.self_improvement, 'color': Colors.purple, 'subCategories': ['Yoga', 'Pilates', 'Tir à l\'arc', 'Golf'], 'mesure': 'RELACHEMENT',},
    {'name': 'Performances', 'icon': Icons.analytics, 'color': Colors.orange, 'desc': '(Classement des athlètes)', 'subCategories': <String>[], 'mesure': 'AUCUNE',},
  ];

  String _description(Map<String, dynamic> cat) =>
      cat['desc'] ?? '(${List<String>.from(cat['subCategories']).join(', ')})';

  /// Icône de batterie qui suit le niveau réel (inconnu, faible, puis par paliers).
  IconData _batteryIcon(int? niveau) => iconeBatterie(niveau);

  // ✅ Bloc IA : ouvre IaResultScreen si un profil existe, sinon le questionnaire
  void _onIaTap() {
    if (_profilExistant != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IaResultScreen(
            profil: _profilExistant!,
            historique: _historiqueProfils,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const QuestionnaireScreen()),
      );
    }
  }

  /// Ferme la session puis ouvre [destination].
  /// - « Changer de compte » : directement l'écran de connexion, pour entrer un autre compte ;
  /// - « Se déconnecter » / « Quitter la démo » : retour à la page d'accueil de l'appli.
  Future<void> _closeSession(Widget destination) async {
    Navigator.pop(context); // ferme le menu
    BrassardActif.liberer(); // le brassard appartient à la session : on le déconnecte
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => destination),
      (route) => false,
    );
  }

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.orange,
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                      Text(Api.isDemo ? "Compte de démonstration" : "Compte actif",
                        style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history, color: Colors.orange, size: 22),
                ),
                title: const Text("Mes séances", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirHistorique();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights, color: Colors.green, size: 22),
                ),
                title: const Text("Mon évolution", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EvolutionScreen()));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.accessibility_new, color: Colors.purple, size: 22),
                ),
                title: const Text("Réglages et accessibilité", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReglagesScreen()));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_book, color: Colors.amber, size: 22),
                ),
                title: const Text("Mode d'emploi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text("Poser le brassard, calibrer, natation, carnet (PDF)",
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirModeEmploi();
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield_outlined, color: Colors.teal, size: 22),
                ),
                title: const Text("Mon compte et mes données", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const CompteScreen()));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.switch_account, color: Colors.blue, size: 22),
                ),
                title: Text(Api.isDemo ? "Se connecter avec un compte" : "Changer de compte",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text("Ouvre l'écran de connexion",
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () => _closeSession(const LoginScreen()),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.logout, color: Colors.red, size: 22),
                ),
                title: Text(Api.isDemo ? "Quitter la démo" : "Se déconnecter",
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                subtitle: const Text("Retour à la page d'accueil",
                  style: TextStyle(color: Colors.white38, fontSize: 11)),
                onTap: () => _closeSession(const LandingScreen()),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ATHLETIX-DATA', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange[800],
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Mes séances',
            icon: const Icon(Icons.history),
            onPressed: _ouvrirHistorique,
          ),
        ],
      ),
      body: Column(
        children: [
          if (Api.isDemo)
            Container(
              width: double.infinity,
              color: Colors.amber[700],
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Text(
                "MODE DÉMO — données fictives, aucun serveur",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: _showProfileMenu,
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.orange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(userName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            const Text("Compte", style: TextStyle(color: Colors.white54, fontSize: 10)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                ValueListenableBuilder<SourceBrassard?>(
                  valueListenable: BrassardActif.courant,
                  builder: (context, source, _) {
                    final niveau = source?.batteriePct ?? batteryLevel;
                    return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Icon(_batteryIcon(niveau),
                        color: Colors.white70, size: 18),
                      const SizedBox(width: 6),
                      Text(niveau == null ? "—" : "$niveau%",
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                );
                  },
                ),
              ],
            ),
          ),
          const _BatteriesAppareils(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ValueListenableBuilder<SourceBrassard?>(
              valueListenable: BrassardActif.courant,
              builder: (context, source, _) {
                final relie = source != null || isConnected;
                final texte = source == null
                    ? (isConnected ? "BRASSARD SYNCHRONISÉ" : "BRASSARD NON RELIÉ · TOUCHER POUR LE CHOISIR")
                    : source.simule
                        ? "BRASSARD SIMULÉ ACTIF"
                        : "${source.nom.toUpperCase()} RELIÉ";
                final couleur = source?.simule == true ? Colors.amber : (relie ? Colors.green : Colors.red);
                return InkWell(
                  onTap: _ouvrirBrassard,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: couleur, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(relie ? Icons.bluetooth_connected : Icons.bluetooth_disabled, color: couleur, size: 20),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(texte,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.chevron_right, color: Colors.white38, size: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: CarteSemaine(
              onOuvrir: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EvolutionScreen())),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: GestureDetector(
              onTap: _onIaTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blueGrey[900]!, Colors.blueGrey[800]!],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.blue),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _profilExistant != null ? "CONSEILS PERSONNALISÉS" : "CONSEIL DE TON IA",
                            style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(aiMessage, style: TextStyle(color: Colors.blue[100], fontSize: 11)),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 14),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 0.9,
              ),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                return InkWell(
                  onTap: () {
                    if (cat['name'] == 'Performances') {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ClassementScreen()));
                    } else {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) => SelectionScreen(
                          categoryName: cat['name'],
                          categoryColor: cat['color'],
                          subCategories: List<String>.from(cat['subCategories'] ?? []),
                          categoryMesure: cat['mesure'],
                        ),
                      ));
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: (cat['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: cat['color'], width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(cat['icon'], size: 45, color: cat['color']),
                        const SizedBox(height: 10),
                        Text(cat['name'], textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13)),
                        const SizedBox(height: 5),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(_description(cat), textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 9, color: Colors.white70)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


/// Batterie de la montre et de la ceinture cardio, visible sur l'accueil quand elles sont reliées.
class _BatteriesAppareils extends StatelessWidget {
  const _BatteriesAppareils();

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<MontrePodometre?>(
        valueListenable: MontrePodometre.active,
        builder: (context, montre, _) => ValueListenableBuilder<CeintureCardio?>(
          valueListenable: CeintureCardio.active,
          builder: (context, ceinture, _) {
            if (montre == null && ceinture == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                if (montre != null)
                  ValueListenableBuilder<int?>(
                    valueListenable: montre.batterie,
                    builder: (context, b, _) => PastilleBatterie(b, libelle: 'Montre'),
                  ),
                if (ceinture != null)
                  ValueListenableBuilder<int?>(
                    valueListenable: ceinture.batterie,
                    builder: (context, b, _) => PastilleBatterie(b, libelle: ceinture.nom.length > 14 ? 'Cardio' : ceinture.nom),
                  ),
              ]),
            );
          },
        ),
      );
}
