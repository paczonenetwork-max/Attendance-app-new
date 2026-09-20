
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Worker {
  String id, name;
  Worker({required this.id, required this.name});
  Map<String,dynamic> toJson()=>{'id':id,'name':name};
  factory Worker.fromJson(Map<String,dynamic> j)=>Worker(id:j['id'],name:j['name']);
}
class Att {
  String status,inTime,outTime; int late,ot;
  Att({required this.status,this.inTime='',this.outTime='',this.late=0,this.ot=0});
  Map<String,dynamic> toJson()=>{'status':status,'in':inTime,'out':outTime,'late':late,'ot':ot};
  factory Att.fromJson(Map<String,dynamic> j)=>Att(status:j['status']??'absent',inTime:j['in']??'',outTime:j['out']??'',late:j['late']??0,ot:j['ot']??0);
}
void main()=>runApp(const App());

class App extends StatefulWidget{const App({super.key});@override State<App> createState()=>_AppState();}
class _AppState extends State<App>{
 ThemeMode mode=ThemeMode.light;
 @override Widget build(BuildContext c)=>MaterialApp(debugShowCheckedModeBanner:false,title:'Factory Attendance',
 themeMode:mode,theme:ThemeData(useMaterial3:true,colorSchemeSeed:Colors.indigo),
 darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorSchemeSeed:Colors.indigo),
 home:Home(toggle:()=>setState(()=>mode=mode==ThemeMode.light?ThemeMode.dark:ThemeMode.light)));
}

class Home extends StatefulWidget{final VoidCallback toggle;const Home({super.key,required this.toggle});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{
 int tab=0; List<Worker> workers=[]; Map<String,Map<String,Att>> rec={}; bool loading=true;
 String key(DateTime d)=>'${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
 String get today=>key(DateTime.now());
 @override void initState(){super.initState();load();}
 Future<void> load()async{final p=await SharedPreferences.getInstance();final w=p.getString('workers'),r=p.getString('records');
 if(w!=null)workers=(jsonDecode(w) as List).map((e)=>Worker.fromJson(e)).toList();
 if(r!=null){final x=jsonDecode(r) as Map<String,dynamic>;rec=x.map((d,v)=>MapEntry(d,(v as Map<String,dynamic>).map((id,a)=>MapEntry(id,Att.fromJson(a)))));}
 setState(()=>loading=false);}
 Future<void> save()async{final p=await SharedPreferences.getInstance();await p.setString('workers',jsonEncode(workers.map((w)=>w.toJson()).toList()));await p.setString('records',jsonEncode(rec.map((d,v)=>MapEntry(d,v.map((id,a)=>MapEntry(id,a.toJson()))))));}
 int mins(String s){if(s.isEmpty)return 0;final p=s.split(':');return int.parse(p[0])*60+int.parse(p[1]);}
 String dur(int m)=>'${m~/60}h ${m%60}m';
 Att? getA(String d,String id)=>rec[d]?[id];
 void setA(String d,String id,Att a){rec.putIfAbsent(d,()=>{});rec[d]![id]=a;save();setState((){});}
 int lateFor(String input)=> (mins(input)-540).clamp(0,1440);
 int otFor(String input)=> (mins(input)-1050).clamp(0,1440); // 17:30 after 8h duty + 30m lunch
 Future<void> workerDialog({Worker? edit})async{
  final n=TextEditingController(text:edit?.name??''),i=TextEditingController(text:edit?.id??'');
  await showDialog(context:context,builder:(c)=>AlertDialog(title:Text(edit==null?'Add Worker':'Edit Worker'),content:Column(mainAxisSize:MainAxisSize.min,children:[
   TextField(controller:n,decoration:const InputDecoration(labelText:'Worker name')),
   TextField(controller:i,enabled:edit==null,decoration:const InputDecoration(labelText:'Worker ID')),
  ]),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:(){
   if(n.text.trim().isEmpty||i.text.trim().isEmpty)return;
   setState(()=>edit==null?workers.add(Worker(id:i.text.trim(),name:n.text.trim())):edit.name=n.text.trim());save();Navigator.pop(c);
  },child:const Text('Save'))]));}
 Future<void> remove(Worker w)async{final ok=await showDialog<bool>(context:context,builder:(c)=>AlertDialog(title:const Text('Remove worker?'),content:Text('Remove ${w.name}?'),actions:[TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('Remove'))]));if(ok==true){setState((){workers.removeWhere((x)=>x.id==w.id);for(final d in rec.keys)rec[d]!.remove(w.id);});save();}}
 Future<void> attendance(Worker w)async{
  final a=getA(today,w.id);String status=a?.status??'present';final inc=TextEditingController(text:a?.inTime??'09:00'),outc=TextEditingController(text:a?.outTime??'17:30');
  await showDialog(context:context,builder:(c)=>StatefulBuilder(builder:(c,sd)=>AlertDialog(title:Text(w.name),content:SingleChildScrollView(child:Column(children:[
   DropdownButtonFormField<String>(value:status,items:const['present','absent','halfDay','leave','weeklyOff'].map((x)=>DropdownMenuItem(value:x,child:Text(x=='halfDay'?'Half Day':x=='weeklyOff'?'Weekly Off':x[0].toUpperCase()+x.substring(1)))).toList(),onChanged:(v)=>sd(()=>status=v!),decoration:const InputDecoration(labelText:'Status')),
   if(status=='present'||status=='halfDay')...[
    TextField(controller:inc,decoration:const InputDecoration(labelText:'In time (HH:MM)')),
    TextField(controller:outc,decoration:const InputDecoration(labelText:'Out time (HH:MM)')),
   ],const SizedBox(height:8),const Text('Duty: 8 hours + 30 min lunch. Late/OT calculated automatically.')
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:(){
   int l=0,o=0;if(status=='present'||status=='halfDay'){l=lateFor(inc.text);o=otFor(outc.text);}
   setA(today,w.id,Att(status:status,inTime:inc.text,outTime:outc.text,late:l,ot:o));Navigator.pop(c);
  },child:const Text('Save'))]));
 }
 Widget dash(){
  final a=rec[today]??{};int p=0,ab=0,late=0,ot=0;for(final w in workers){final x=a[w.id];if(x?.status=='present')p++;if(x?.status=='absent'||x==null)ab++;late+=x?.late??0;ot+=x?.ot??0;}
  return ListView(padding:const EdgeInsets.all(16),children:[
   Text('Today • $today',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
   Row(children:[stat('Workers',workers.length,Icons.people),stat('Present',p,Icons.check_circle),stat('Absent',ab,Icons.cancel)]),
   Row(children:[stat('Late',late,Icons.schedule,suffix:' min'),stat('Overtime',ot,Icons.timer,suffix:' min')]),
   const SizedBox(height:16),FilledButton.icon(onPressed:()=>setState(()=>tab=1),icon:const Icon(Icons.person_add),label:const Text('Manage Workers')),
   const SizedBox(height:8),FilledButton.icon(onPressed:()=>setState(()=>tab=2),icon:const Icon(Icons.fact_check),label:const Text('Mark Today Attendance')),
  ]);}
 Widget stat(String title,int v,IconData icon,{String suffix=''})=>Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon),Text('$v$suffix',style:Theme.of(context).textTheme.headlineSmall),Text(title)]))));
 Widget workersPage()=>ListView(padding:const EdgeInsets.all(12),children:[FilledButton.icon(onPressed:()=>workerDialog(),icon:const Icon(Icons.add),label:const Text('Add Worker')),const SizedBox(height:8),...workers.map((w)=>Card(child:ListTile(title:Text(w.name),subtitle:Text('ID: ${w.id}'),trailing:Wrap(children:[IconButton(onPressed:()=>workerDialog(edit:w),icon:const Icon(Icons.edit)),IconButton(onPressed:()=>remove(w),icon:const Icon(Icons.delete))]))))]);
 Widget attendancePage()=>ListView(padding:const EdgeInsets.all(12),children:[Text('Today: $today',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:8),...workers.map((w){final a=getA(today,w.id);return Card(child:ListTile(title:Text(w.name),subtitle:Text(a==null?'Not marked':'${a.status} • Late ${a.late}m • OT ${a.ot}m'),trailing:FilledButton(onPressed:()=>attendance(w),child:Text(a==null?'Mark':'Edit'))));})]);
 Widget chartPage(){
  final now=DateTime.now();final days=List.generate(7,(i)=>DateTime(now.year,now.month,now.day-now.weekday+1+i));
  final vals=days.map((d){final m=rec[key(d)]??{};return m.values.where((a)=>a.status=='present').length.toDouble();}).toList();
  return Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Weekly Present Chart',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:20),Expanded(child:BarChart(BarChartData(barGroups:List.generate(7,(i)=>BarChartGroupData(x:i,barRods:[BarChartRodData(toY:vals[i],width:22,borderRadius:BorderRadius.circular(4))])),titlesData:FlTitlesData(bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,getTitlesWidget:(v,m)=>Padding(padding:const EdgeInsets.only(top:8),child:Text(['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][v.toInt()])))),leftTitles:const AxisTitles(sideTitles:SideTitles(showTitles:true)),topTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false)),rightTitles:const AxisTitles(sideTitles:SideTitles(showTitles:false))))))]));}
 @override Widget build(BuildContext c){if(loading)return const Scaffold(body:Center(child:CircularProgressIndicator()));final pages=[dash(),workersPage(),attendancePage(),chartPage()];return Scaffold(appBar:AppBar(title:const Text('Factory Attendance'),actions:[IconButton(onPressed:widget.toggle,icon:const Icon(Icons.dark_mode))]),body:pages[tab],bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),destinations:const[NavigationDestination(icon:Icon(Icons.dashboard),label:'Home'),NavigationDestination(icon:Icon(Icons.people),label:'Workers'),NavigationDestination(icon:Icon(Icons.fact_check),label:'Attendance'),NavigationDestination(icon:Icon(Icons.bar_chart),label:'Weekly')]),);}
}
