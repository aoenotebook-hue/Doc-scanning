import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../app_strings.dart';
import '../core/export_service.dart';
import '../core/models.dart';
import '../core/platform_bridge.dart';

class ExportScreen extends StatefulWidget { const ExportScreen({required this.draft, super.key}); final DocumentDraft draft; @override State<ExportScreen> createState()=>_ExportScreenState(); }
class _ExportScreenState extends State<ExportScreen> {
  ExportOptions options=const ExportOptions(); late final TextEditingController name; int? estimate; bool busy=false;
  @override void initState(){super.initState();name=TextEditingController(text:widget.draft.title);_estimate();}
  @override void dispose(){name.dispose();super.dispose();}
  Future<void> _estimate()async{final value=await ExportService().estimate(widget.draft,options);if(mounted)setState(()=>estimate=value);}
  String get extension=>options.format==ExportFormat.pdf?'pdf':'zip'; String get mime=>options.format==ExportFormat.pdf?'application/pdf':'application/zip';
  Future<GeneratedExport?> _generate()async{setState(()=>busy=true);try{return await ExportService().generate(widget.draft,options,name.text);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S.of(context).t('Could not generate the file. Your draft is unchanged.','สร้างไฟล์ไม่ได้ ฉบับร่างของคุณไม่เปลี่ยนแปลง'))));return null;}finally{if(mounted)setState(()=>busy=false);}}
  Future<void> _save()async{final out=await _generate();if(out==null)return;try{final saved=await PlatformBridge().saveAs(out.path,mime,'${name.text}.$extension');if(!mounted)return;ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(saved==true?S.of(context).t('Saved successfully (${_size(out.bytes)})','บันทึกสำเร็จ (${_size(out.bytes)})'):S.of(context).t('Nothing was saved. Your draft is still available.','ไม่ได้บันทึกไฟล์ ฉบับร่างของคุณยังอยู่'))));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S.of(context).t('The destination could not save this file. Try another location.','ปลายทางบันทึกไฟล์ไม่ได้ โปรดลองตำแหน่งอื่น'))));}}
  Future<void> _share()async{final out=await _generate();if(out!=null)await SharePlus.instance.share(ShareParams(files:[XFile(out.path)],subject:name.text));}
  @override Widget build(BuildContext context){final s=S.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('Export','ส่งออก'))),body:ListView(padding:const EdgeInsets.all(20),children:[
    TextField(controller:name,decoration:InputDecoration(labelText:s.t('Filename','ชื่อไฟล์'),suffixText:'.$extension')),
    const SizedBox(height:20),Text(s.t('File type','ชนิดไฟล์'),style:Theme.of(context).textTheme.titleMedium),SegmentedButton<ExportFormat>(segments:ExportFormat.values.map((v)=>ButtonSegment(value:v,label:Text(v.name.toUpperCase()))).toList(),selected:{options.format},onSelectionChanged:(v){setState(()=>options=options.copyWith(format:v.first));_estimate();}),
    if(options.format!=ExportFormat.pdf)Padding(padding:const EdgeInsets.only(top:8),child:Text(s.t('Multiple pages are exported together in an explicit ZIP; every page is included. PNG is lossless—reduce dimensions to reduce its size.','หลายหน้าจะรวมใน ZIP และรวมครบทุกหน้า PNG ไม่สูญเสียคุณภาพ—ลดขนาดภาพเพื่อลดขนาดไฟล์'))),
    const SizedBox(height:20),DropdownButtonFormField<PageSize>(initialValue:options.pageSize,decoration:InputDecoration(labelText:s.t('Page size','ขนาดหน้า')),items:PageSize.values.map((v)=>DropdownMenuItem(value:v,child:Text(v.name))).toList(),onChanged:(v){setState(()=>options=options.copyWith(pageSize:v));_estimate();}),
    const SizedBox(height:16),DropdownButtonFormField<OutputResolution>(initialValue:options.resolution,decoration:InputDecoration(labelText:s.t('Resolution','ความละเอียด')),items:OutputResolution.values.map((v)=>DropdownMenuItem(value:v,child:Text(v.name))).toList(),onChanged:(v){setState(()=>options=options.copyWith(resolution:v));_estimate();}),
    if(options.format==ExportFormat.pdf)...[const SizedBox(height:16),DropdownButtonFormField<int>(initialValue:options.dpi,decoration:const InputDecoration(labelText:'PDF DPI'),items:[150,200,300].map((v)=>DropdownMenuItem(value:v,child:Text('$v DPI'))).toList(),onChanged:(v){setState(()=>options=options.copyWith(dpi:v));_estimate();})],
    if(options.format!=ExportFormat.png)...[const SizedBox(height:18),Text(s.t('JPEG compression: ${options.jpegQuality}%','การบีบอัด JPEG: ${options.jpegQuality}%')),Slider(value:options.jpegQuality.toDouble(),min:45,max:95,divisions:10,label:'${options.jpegQuality}',onChanged:(v){setState(()=>options=options.copyWith(jpegQuality:v.round()));_estimate();})],
    const SizedBox(height:8),Text(s.t('Increasing output resolution cannot restore detail missing from the source. Aspect ratio is preserved.','การเพิ่มความละเอียดไม่อาจคืนรายละเอียดที่ไม่มีในต้นฉบับ อัตราส่วนภาพจะคงเดิม')),const SizedBox(height:16),Text('${s.t('Estimated size','ขนาดโดยประมาณ')}: ${estimate==null?'…':_size(estimate!)}',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:24),
    if(busy)const Center(child:CircularProgressIndicator())else Row(children:[Expanded(child:FilledButton.icon(onPressed:_save,icon:const Icon(Icons.save_alt),label:Text(s.t('Save As','บันทึกเป็น')))),const SizedBox(width:12),Expanded(child:OutlinedButton.icon(onPressed:_share,icon:const Icon(Icons.share),label:Text(s.t('Share','แชร์'))))])
  ]));}
  String _size(int bytes)=>bytes<1048576?'${(bytes/1024).toStringAsFixed(1)} KB':'${(bytes/1048576).toStringAsFixed(1)} MB';
}
