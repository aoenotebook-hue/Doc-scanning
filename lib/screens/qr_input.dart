import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_strings.dart';
import 'qr_result.dart';

class QrInputScreen extends StatefulWidget { const QrInputScreen({super.key}); @override State<QrInputScreen> createState()=>_QrInputScreenState(); }
class _QrInputScreenState extends State<QrInputScreen> {
  final scanner=MobileScannerController(formats:const [BarcodeFormat.qrCode],detectionSpeed:DetectionSpeed.noDuplicates); bool busy=false;
  Future<void> _decode(String path)async{setState(()=>busy=true);final capture=await scanner.analyzeImage(path);if(!mounted)return;setState(()=>busy=false);final values=(capture?.barcodes??const <Barcode>[]).map((b)=>b.rawValue).whereType<String>().toSet().toList();if(values.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(S.of(context).t('No QR code found. Crop closer to the code and try again.','ไม่พบคิวอาร์โค้ด ครอบตัดให้ใกล้โค้ดแล้วลองอีกครั้ง'))));}else{await Navigator.push(context,MaterialPageRoute(builder:(_)=>QrResultScreen(values:values)));}}
  Future<void> _photo()async{final value=await ImagePicker().pickImage(source:ImageSource.gallery,requestFullMetadata:false);if(value!=null)await _decode(value.path);}
  Future<void> _file()async{final value=await FilePicker.platform.pickFiles(type:FileType.image);final path=value?.files.single.path;if(path!=null)await _decode(path);}
  void _live(BarcodeCapture capture){final values=capture.barcodes.map((b)=>b.rawValue).whereType<String>().toSet().toList();if(values.isNotEmpty){scanner.stop();Navigator.push(context,MaterialPageRoute(builder:(_)=>QrResultScreen(values:values))).then((_)=>scanner.start());}}
  @override void dispose(){scanner.dispose();super.dispose();}
  @override Widget build(BuildContext context){final s=S.of(context);return Scaffold(appBar:AppBar(title:Text(s.t('Read QR','อ่านคิวอาร์'))),body:Column(children:[Expanded(child:Stack(fit:StackFit.expand,children:[MobileScanner(controller:scanner,onDetect:_live,errorBuilder:(_,error)=>Center(child:Padding(padding:const EdgeInsets.all(24),child:Text(s.t('Camera is unavailable. Choose an image instead.','ใช้กล้องไม่ได้ โปรดเลือกรูปภาพแทน'))))),Center(child:Container(width:240,height:240,decoration:BoxDecoration(border:Border.all(color:Colors.white,width:3),borderRadius:BorderRadius.circular(20)))),if(busy)const ColoredBox(color:Colors.black54,child:Center(child:CircularProgressIndicator()))])),Padding(padding:const EdgeInsets.all(16),child:Column(children:[Text(s.t('Nothing opens automatically. You will review every result first.','จะไม่มีการเปิดอัตโนมัติ คุณจะตรวจสอบผลลัพธ์ก่อนเสมอ')),const SizedBox(height:12),Row(children:[Expanded(child:FilledButton.icon(onPressed:_photo,icon:const Icon(Icons.photo_outlined),label:Text(s.t('Photos','รูปภาพ')))),const SizedBox(width:12),Expanded(child:OutlinedButton.icon(onPressed:_file,icon:const Icon(Icons.folder_outlined),label:Text(s.t('Files','ไฟล์'))))]),const SizedBox(height:8),Text(s.t('Choose a screenshot here, or share an image to Scan & Open from another app.','เลือกภาพหน้าจอที่นี่ หรือแชร์รูปภาพมายังสแกนและเปิดจากแอปอื่น'))]))]));}
}
