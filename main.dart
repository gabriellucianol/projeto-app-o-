
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DB.instance.db;
  runApp(const OrganizaApp());
}

class OrganizaApp extends StatelessWidget {
  const OrganizaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Organiza+',
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF315C9B)),
      scaffoldBackgroundColor: const Color(0xFFF5F7FB),
    ),
    home: const WelcomePage(),
  );
}

class DB {
  DB._();
  static final DB instance = DB._();
  Database? _database;
  Future<Database> get db async {
    if (_database != null) return _database!;
    final dir = await getDatabasesPath();
    _database = await openDatabase(p.join(dir, 'organiza_mais.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE tarefas (id INTEGER PRIMARY KEY AUTOINCREMENT, titulo TEXT NOT NULL, descricao TEXT, data TEXT NOT NULL, concluida INTEGER NOT NULL DEFAULT 0)');
        await db.execute('CREATE TABLE contas (id INTEGER PRIMARY KEY AUTOINCREMENT, descricao TEXT NOT NULL, valor REAL NOT NULL, vencimento TEXT NOT NULL, paga INTEGER NOT NULL DEFAULT 0)');
      });
    return _database!;
  }
  Future<List<Map<String,Object?>>> list(String table) async =>
      (await db).query(table, orderBy: table == 'tarefas' ? 'data ASC' : 'vencimento ASC');
  Future<void> addTask(String title, String desc, String date) async =>
      (await db).insert('tarefas', {'titulo':title,'descricao':desc,'data':date,'concluida':0});
  Future<void> addBill(String desc, double value, String date) async =>
      (await db).insert('contas', {'descricao':desc,'valor':value,'vencimento':date,'paga':0});
  Future<void> status(String table, int id, String column, bool value) async =>
      (await db).update(table, {column:value ? 1 : 0}, where:'id=?', whereArgs:[id]);
  Future<void> remove(String table, int id) async =>
      (await db).delete(table, where:'id=?', whereArgs:[id]);
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(mainAxisAlignment:MainAxisAlignment.center, children:[
        const CircleAvatar(radius:55, backgroundColor:Color(0xFFE3ECFA),
          child:Icon(Icons.checklist_rounded,size:62,color:Color(0xFF315C9B))),
        const SizedBox(height:22),
        const Text('Organiza+',style:TextStyle(fontSize:34,fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        const Text('Organize suas tarefas e mantenha suas contas em dia.',textAlign:TextAlign.center),
        const SizedBox(height:30),
        SizedBox(width:double.infinity,child:FilledButton(
          onPressed:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>const LoginPage())),
          child:const Padding(padding:EdgeInsets.all(14),child:Text('Começar')))),
      ]),
    ))),
  );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState()=>_LoginPageState();
}
class _LoginPageState extends State<LoginPage>{
  final name=TextEditingController(text:'Usuário');
  @override
  void dispose(){name.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Entrar')),
    body:Padding(padding:const EdgeInsets.all(24),child:Column(
      mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        const Icon(Icons.account_circle_outlined,size:80,color:Color(0xFF315C9B)),
        const Text('Bem-vindo(a)!',textAlign:TextAlign.center,style:TextStyle(fontSize:25,fontWeight:FontWeight.bold)),
        const SizedBox(height:22),
        TextField(controller:name,decoration:const InputDecoration(labelText:'Nome de usuário',prefixIcon:Icon(Icons.person_outline))),
        const SizedBox(height:16),
        FilledButton(onPressed:()=>Navigator.pushReplacement(context,MaterialPageRoute(builder:(_)=>MainPage(user:name.text.trim().isEmpty?'Usuário':name.text.trim()))),child:const Text('Acessar aplicativo')),
        const SizedBox(height:10),
        const Text('Tela demonstrativa: ainda não possui senha ou autenticação real.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,color:Colors.black54)),
      ])),
  );
}

class MainPage extends StatefulWidget{
  final String user;
  const MainPage({super.key,required this.user});
  @override
  State<MainPage> createState()=>_MainPageState();
}
class _MainPageState extends State<MainPage>{
  int index=0;
  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Organiza+',style:TextStyle(fontWeight:FontWeight.bold))),
    body: [Dashboard(user:widget.user),const TasksPage(),const BillsPage()][index],
    bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(v)=>setState(()=>index=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.home_outlined),label:'Início'),
      NavigationDestination(icon:Icon(Icons.check_circle_outline),label:'Tarefas'),
      NavigationDestination(icon:Icon(Icons.receipt_long_outlined),label:'Contas'),
    ]),
  );
}

class Dashboard extends StatefulWidget{
  final String user;
  const Dashboard({super.key,required this.user});
  @override
  State<Dashboard> createState()=>_DashboardState();
}
class _DashboardState extends State<Dashboard>{
  int tasks=0,bills=0; double total=0;
  @override
  void initState(){super.initState();load();}
  Future<void> load()async{
    final t=await DB.instance.list('tarefas'), b=await DB.instance.list('contas');
    if(!mounted)return;
    setState((){
      tasks=t.where((e)=>e['concluida']==0).length;
      final pending=b.where((e)=>e['paga']==0);
      bills=pending.length;
      total=pending.fold<double>(0,(s,e)=>s+(e['valor'] as num).toDouble());
    });
  }
  @override
  Widget build(BuildContext context)=>RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(20),children:[
    Text('Olá, ${widget.user}!',style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),
    const Text('Veja um resumo da sua organização.'),
    const SizedBox(height:20),
    _card(Icons.checklist,'Tarefas pendentes','$tasks','Atividades que ainda precisam ser feitas'),
    _card(Icons.receipt_long,'Contas em aberto','$bills','Total: R\$ ${total.toStringAsFixed(2).replaceAll('.',',')}'),
    const SizedBox(height:14),
    const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Dica: cadastre suas atividades e seus vencimentos para acompanhar tudo em um só lugar.'))),
  ]));
  Widget _card(IconData icon,String title,String value,String sub)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[
    CircleAvatar(backgroundColor:const Color(0xFFE3ECFA),child:Icon(icon,color:const Color(0xFF315C9B))),
    const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title),Text(value,style:const TextStyle(fontSize:25,fontWeight:FontWeight.bold)),Text(sub,style:const TextStyle(fontSize:12,color:Colors.black54)),
    ]))
  ])));
}

String dateText(DateTime d)=>'${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

class TasksPage extends StatefulWidget{
  const TasksPage({super.key});
  @override
  State<TasksPage> createState()=>_TasksPageState();
}
class _TasksPageState extends State<TasksPage>{
  List<Map<String,Object?>> items=[];
  @override
  void initState(){super.initState();load();}
  Future<void> load()async{final v=await DB.instance.list('tarefas');if(mounted)setState(()=>items=v);}
  Future<void> add()async{final ok=await showDialog<bool>(context:context,builder:(_)=>const TaskDialog());if(ok==true)load();}
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,
    floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('Nova tarefa')),
    body:items.isEmpty?const Center(child:Text('Nenhuma tarefa cadastrada.')):Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Row(children:[
        const Expanded(child:Text('Minhas tarefas',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold))),
        Chip(label:Text('${items.where((e)=>e['concluida']==0).length} pendentes')),
      ])),
      Expanded(child:ListView.builder(padding:const EdgeInsets.fromLTRB(12,0,12,85),itemCount:items.length,itemBuilder:(context,i){
        final e=items[i],done=e['concluida']==1;
        return Card(child:ListTile(
          leading:Checkbox(value:done,onChanged:(v)async{await DB.instance.status('tarefas',e['id'] as int,'concluida',v??false);load();}),
          title:Text(e['titulo'] as String,style:TextStyle(decoration:done?TextDecoration.lineThrough:null,fontWeight:FontWeight.w600)),
          subtitle:Text('${e['descricao']??''}\nData: ${e['data']}'),isThreeLine:true,
          trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()async{await DB.instance.remove('tarefas',e['id'] as int);load();}),
        ));
      }))
    ]));
}

class TaskDialog extends StatefulWidget{
  const TaskDialog({super.key});
  @override
  State<TaskDialog> createState()=>_TaskDialogState();
}
class _TaskDialogState extends State<TaskDialog>{
  final title=TextEditingController(),desc=TextEditingController();
  DateTime date=DateTime.now();
  @override
  void dispose(){title.dispose();desc.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AlertDialog(title:const Text('Cadastrar tarefa'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:title,decoration:const InputDecoration(labelText:'Título')),
    const SizedBox(height:10),TextField(controller:desc,maxLines:2,decoration:const InputDecoration(labelText:'Descrição')),
    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Data da tarefa'),subtitle:Text(dateText(date)),trailing:IconButton(icon:const Icon(Icons.calendar_month),onPressed:()async{
      final d=await showDatePicker(context:context,initialDate:date,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)setState(()=>date=d);
    })),
  ])),actions:[
    TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
    FilledButton(onPressed:()async{if(title.text.trim().isEmpty)return;await DB.instance.addTask(title.text.trim(),desc.text.trim(),dateText(date));if(context.mounted)Navigator.pop(context,true);},child:const Text('Salvar')),
  ]);
}

class BillsPage extends StatefulWidget{
  const BillsPage({super.key});
  @override
  State<BillsPage> createState()=>_BillsPageState();
}
class _BillsPageState extends State<BillsPage>{
  List<Map<String,Object?>> items=[];
  @override
  void initState(){super.initState();load();}
  Future<void> load()async{final v=await DB.instance.list('contas');if(mounted)setState(()=>items=v);}
  Future<void> add()async{final ok=await showDialog<bool>(context:context,builder:(_)=>const BillDialog());if(ok==true)load();}
  @override
  Widget build(BuildContext context)=>Scaffold(backgroundColor:Colors.transparent,
    floatingActionButton:FloatingActionButton.extended(onPressed:add,icon:const Icon(Icons.add),label:const Text('Nova conta')),
    body:items.isEmpty?const Center(child:Text('Nenhuma conta cadastrada.')):Column(children:[
      Padding(padding:const EdgeInsets.all(16),child:Row(children:[
        const Expanded(child:Text('Minhas contas',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold))),
        Chip(label:Text('${items.where((e)=>e['paga']==0).length} pendentes')),
      ])),
      Expanded(child:ListView.builder(padding:const EdgeInsets.fromLTRB(12,0,12,85),itemCount:items.length,itemBuilder:(context,i){
        final e=items[i],paid=e['paga']==1;final value=(e['valor'] as num).toDouble();
        return Card(child:ListTile(
          leading:Checkbox(value:paid,onChanged:(v)async{await DB.instance.status('contas',e['id'] as int,'paga',v??false);load();}),
          title:Text(e['descricao'] as String,style:TextStyle(decoration:paid?TextDecoration.lineThrough:null,fontWeight:FontWeight.w600)),
          subtitle:Text('Vencimento: ${e['vencimento']}\n${paid?'Paga':'Pendente'}'),isThreeLine:true,
          trailing:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
            Text('R\$ ${value.toStringAsFixed(2).replaceAll('.',',')}',style:const TextStyle(fontWeight:FontWeight.bold)),
            IconButton(visualDensity:VisualDensity.compact,icon:const Icon(Icons.delete_outline,size:20),onPressed:()async{await DB.instance.remove('contas',e['id'] as int);load();}),
          ]),
        ));
      }))
    ]));
}

class BillDialog extends StatefulWidget{
  const BillDialog({super.key});
  @override
  State<BillDialog> createState()=>_BillDialogState();
}
class _BillDialogState extends State<BillDialog>{
  final desc=TextEditingController(),value=TextEditingController();
  DateTime due=DateTime.now();
  @override
  void dispose(){desc.dispose();value.dispose();super.dispose();}
  @override
  Widget build(BuildContext context)=>AlertDialog(title:const Text('Cadastrar conta'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
    TextField(controller:desc,decoration:const InputDecoration(labelText:'Descrição')),
    const SizedBox(height:10),TextField(controller:value,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Valor',prefixText:'R\$ ')),
    ListTile(contentPadding:EdgeInsets.zero,title:const Text('Data de vencimento'),subtitle:Text(dateText(due)),trailing:IconButton(icon:const Icon(Icons.calendar_month),onPressed:()async{
      final d=await showDatePicker(context:context,initialDate:due,firstDate:DateTime(2020),lastDate:DateTime(2100));if(d!=null)setState(()=>due=d);
    })),
  ])),actions:[
    TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancelar')),
    FilledButton(onPressed:()async{
      final n=double.tryParse(value.text.trim().replaceAll(',','.'));
      if(desc.text.trim().isEmpty||n==null||n<=0){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Informe uma descrição e um valor válido.')));return;}
      await DB.instance.addBill(desc.text.trim(),n,dateText(due));if(context.mounted)Navigator.pop(context,true);
    },child:const Text('Salvar')),
  ]);
}
