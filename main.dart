import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const OrganizaApp());

// ───────────────────────── Modelos ─────────────────────────

class Tarefa {
  String id;
  String titulo;
  bool concluida;
  DateTime data;

  Tarefa({
    required this.id,
    required this.titulo,
    this.concluida = false,
    required this.data,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'concluida': concluida,
        'data': data.toIso8601String(),
      };

  factory Tarefa.fromJson(Map<String, dynamic> j) => Tarefa(
        id: j['id'],
        titulo: j['titulo'],
        concluida: j['concluida'] ?? false,
        data: DateTime.parse(j['data']),
      );
}

class Conta {
  String id;
  String descricao;
  double valor;
  DateTime vencimento;
  bool paga;

  Conta({
    required this.id,
    required this.descricao,
    required this.valor,
    required this.vencimento,
    this.paga = false,
  });

  bool get vencida => !paga && vencimento.isBefore(hoje());

  Map<String, dynamic> toJson() => {
        'id': id,
        'descricao': descricao,
        'valor': valor,
        'vencimento': vencimento.toIso8601String(),
        'paga': paga,
      };

  factory Conta.fromJson(Map<String, dynamic> j) => Conta(
        id: j['id'],
        descricao: j['descricao'],
        valor: (j['valor'] as num).toDouble(),
        vencimento: DateTime.parse(j['vencimento']),
        paga: j['paga'] ?? false,
      );
}

// ───────────────────────── Utilidades ─────────────────────────

DateTime hoje() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

String fmtData(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

String fmtMoeda(double v) {
  final partes = v.toStringAsFixed(2).split('.');
  final inteiro = partes[0].replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'R\$ $inteiro,${partes[1]}';
}

String novoId() => DateTime.now().microsecondsSinceEpoch.toString();

// ───────────────────────── Armazenamento ─────────────────────────

class Armazenamento extends ChangeNotifier {
  List<Tarefa> tarefas = [];
  List<Conta> contas = [];
  late SharedPreferences _prefs;

  Future<void> carregar() async {
    _prefs = await SharedPreferences.getInstance();
    final t = _prefs.getString('tarefas');
    final c = _prefs.getString('contas');
    if (t != null) {
      tarefas = (jsonDecode(t) as List).map((e) => Tarefa.fromJson(e)).toList();
    }
    if (c != null) {
      contas = (jsonDecode(c) as List).map((e) => Conta.fromJson(e)).toList();
    }
    notifyListeners();
  }

  Future<void> _salvar() async {
    await _prefs.setString(
        'tarefas', jsonEncode(tarefas.map((e) => e.toJson()).toList()));
    await _prefs.setString(
        'contas', jsonEncode(contas.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  void addTarefa(Tarefa t) {
    tarefas.add(t);
    _salvar();
  }

  void alternarTarefa(Tarefa t) {
    t.concluida = !t.concluida;
    _salvar();
  }

  void removerTarefa(Tarefa t) {
    tarefas.remove(t);
    _salvar();
  }

  void addConta(Conta c) {
    contas.add(c);
    _salvar();
  }

  void alternarConta(Conta c) {
    c.paga = !c.paga;
    _salvar();
  }

  void removerConta(Conta c) {
    contas.remove(c);
    _salvar();
  }
}

// ───────────────────────── App ─────────────────────────

class OrganizaApp extends StatelessWidget {
  const OrganizaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Organiza+',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B5BD6)),
      ),
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final store = Armazenamento();
  int aba = 0;

  @override
  void initState() {
    super.initState();
    store.carregar();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Organiza+',
              style: TextStyle(fontWeight: FontWeight.bold)),
          centerTitle: true,
        ),
        body: aba == 0 ? TarefasTela(store: store) : ContasTela(store: store),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => aba == 0
              ? dialogoTarefa(context, store)
              : dialogoConta(context, store),
          icon: const Icon(Icons.add),
          label: Text(aba == 0 ? 'Nova tarefa' : 'Nova conta'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: aba,
          onDestinationSelected: (i) => setState(() => aba = i),
          destinations: const [
            NavigationDestination(
                icon: Icon(Icons.checklist_outlined),
                selectedIcon: Icon(Icons.checklist),
                label: 'Tarefas'),
            NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long),
                label: 'Contas'),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Tarefas ─────────────────────────

class TarefasTela extends StatelessWidget {
  final Armazenamento store;
  const TarefasTela({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final lista = [...store.tarefas]..sort((a, b) {
        if (a.concluida != b.concluida) return a.concluida ? 1 : -1;
        return a.data.compareTo(b.data);
      });
    final feitas = lista.where((t) => t.concluida).length;
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          color: cs.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hoje, ${fmtData(hoje())}',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Text('$feitas de ${lista.length} concluídas',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: lista.isEmpty ? 0 : feitas / lista.length,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Nenhuma tarefa cadastrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final t = lista[i];
                    return Dismissible(
                      key: ValueKey(t.id),
                      direction: DismissDirection.endToStart,
                      background: fundoExcluir(),
                      onDismissed: (_) => store.removerTarefa(t),
                      child: CheckboxListTile(
                        value: t.concluida,
                        onChanged: (_) => store.alternarTarefa(t),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          t.titulo,
                          style: TextStyle(
                            decoration:
                                t.concluida ? TextDecoration.lineThrough : null,
                            color: t.concluida ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(fmtData(t.data)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Widget fundoExcluir() => Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );

Future<void> dialogoTarefa(BuildContext context, Armazenamento store) async {
  final ctrl = TextEditingController();
  DateTime data = hoje();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Nova tarefa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Tarefa'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text(fmtData(data)),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: data,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setS(() => data = d);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final titulo = ctrl.text.trim();
              if (titulo.isEmpty) return;
              store.addTarefa(Tarefa(id: novoId(), titulo: titulo, data: data));
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────── Contas ─────────────────────────

class ContasTela extends StatelessWidget {
  final Armazenamento store;
  const ContasTela({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final lista = [...store.contas]..sort((a, b) {
        if (a.paga != b.paga) return a.paga ? 1 : -1;
        return a.vencimento.compareTo(b.vencimento);
      });
    final pendente =
        lista.where((c) => !c.paga).fold<double>(0, (s, c) => s + c.valor);
    final pago =
        lista.where((c) => c.paga).fold<double>(0, (s, c) => s + c.valor);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                  child: resumo('Pendentes', pendente, Colors.orange.shade100,
                      Colors.orange.shade900)),
              const SizedBox(width: 12),
              Expanded(
                  child: resumo('Pagas', pago, Colors.green.shade100,
                      Colors.green.shade900)),
            ],
          ),
        ),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Nenhuma conta cadastrada.'))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final c = lista[i];
                    final cor = c.paga
                        ? Colors.green
                        : (c.vencida ? Colors.red : Colors.orange);
                    final status = c.paga
                        ? 'Paga'
                        : (c.vencida ? 'Vencida' : 'Pendente');
                    return Dismissible(
                      key: ValueKey(c.id),
                      direction: DismissDirection.endToStart,
                      background: fundoExcluir(),
                      onDismissed: (_) => store.removerConta(c),
                      child: ListTile(
                        leading: Icon(
                            c.paga ? Icons.check_circle : Icons.schedule,
                            color: cor),
                        title: Text(
                          c.descricao,
                          style: TextStyle(
                            decoration:
                                c.paga ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        subtitle: Text(
                            'Vence em ${fmtData(c.vencimento)} • $status',
                            style: TextStyle(color: cor)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(fmtMoeda(c.valor),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            SizedBox(
                              height: 24,
                              child: Switch(
                                value: c.paga,
                                onChanged: (_) => store.alternarConta(c),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget resumo(String titulo, double valor, Color fundo, Color texto) => Card(
        color: fundo,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: TextStyle(color: texto)),
              const SizedBox(height: 4),
              Text(fmtMoeda(valor),
                  style: TextStyle(
                      color: texto, fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
        ),
      );
}

Future<void> dialogoConta(BuildContext context, Armazenamento store) async {
  final descCtrl = TextEditingController();
  final valorCtrl = TextEditingController();
  DateTime venc = hoje();

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Nova conta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descrição'),
            ),
            TextField(
              controller: valorCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.event),
              label: Text('Vencimento: ${fmtData(venc)}'),
              onPressed: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: venc,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (d != null) setS(() => venc = d);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final desc = descCtrl.text.trim();
              final valor =
                  double.tryParse(valorCtrl.text.trim().replaceAll(',', '.'));
              if (desc.isEmpty || valor == null || valor <= 0) return;
              store.addConta(Conta(
                  id: novoId(),
                  descricao: desc,
                  valor: valor,
                  vencimento: venc));
              Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    ),
  );
}