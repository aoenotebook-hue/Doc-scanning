const translations = {
  en: {eyebrow:'PRIVATE • ON-DEVICE',headline:'Paper and QR codes,<br><span>handled privately.</span>',lede:'Scan documents in the mobile app or read a QR image here. Your content is processed on this device—never uploaded.',android:'Get Android release',source:'View source',availability:'Installable releases appear after the repository owner publishes a signed build. iPhone installation requires an owner-signed App Store or TestFlight build.',webTool:'WEB TOOL',qrTitle:'Read a QR without uploading it',qrIntro:'Choose an image or use your camera. Nothing opens automatically; inspect the result first.',dropTitle:'Choose a QR image',dropHint:'Photo, file, or screenshot',choose:'Choose image',camera:'Use camera',stop:'Stop camera',empty:'Your decoded result will appear here.',select:'Select a result',destination:'DESTINATION',open:'Open',copy:'Copy',share:'Share',documents:'Document ready',documentsBody:'Multipage capture, non-destructive edits, filters, PDF, JPG, and PNG in the mobile app.',private:'Private by design',privateBody:'No account, backend, content analytics, or cloud upload. You choose where exports go.',review:'Review before opening',reviewBody:'See the hostname and complete QR payload. Only web, email, and telephone actions are allowed.',footer:'Open source • No uploads • English & Thai',detected:n=>`${n} QR code${n===1?'':'s'} detected`,noQr:'No QR code found. Try a sharper image or crop closer to the code.',unsupported:'This content is shown as text. It cannot be opened by this app.',copied:'Copied to clipboard.',cameraDenied:'Camera is unavailable or permission was denied. Choose an image instead.',notSupported:'This browser cannot decode QR codes locally yet. Use current Chrome or Edge, or install the mobile app.',ready:'QR reading runs locally in supported browsers. Images and decoded contents never leave this device.'},
  th: {eyebrow:'ส่วนตัว • ประมวลผลในเครื่อง',headline:'เอกสารและคิวอาร์<br><span>จัดการอย่างเป็นส่วนตัว</span>',lede:'สแกนเอกสารในแอปมือถือ หรืออ่านรูปคิวอาร์ที่นี่ เนื้อหาประมวลผลในอุปกรณ์นี้และไม่ถูกอัปโหลด',android:'รับรุ่น Android',source:'ดูซอร์สโค้ด',availability:'รุ่นติดตั้งจะแสดงเมื่อเจ้าของเผยแพร่ไฟล์ที่ลงนามแล้ว การติดตั้งบน iPhone ต้องใช้ App Store หรือ TestFlight ที่เจ้าของลงนาม',webTool:'เครื่องมือเว็บ',qrTitle:'อ่านคิวอาร์โดยไม่อัปโหลด',qrIntro:'เลือกรูปภาพหรือใช้กล้อง ระบบจะไม่เปิดผลลัพธ์อัตโนมัติ โปรดตรวจสอบก่อน',dropTitle:'เลือกรูปคิวอาร์',dropHint:'รูปภาพ ไฟล์ หรือภาพหน้าจอ',choose:'เลือกรูปภาพ',camera:'ใช้กล้อง',stop:'หยุดกล้อง',empty:'ผลลัพธ์ที่อ่านได้จะแสดงที่นี่',select:'เลือกผลลัพธ์',destination:'ปลายทาง',open:'เปิด',copy:'คัดลอก',share:'แชร์',documents:'พร้อมสำหรับเอกสาร',documentsBody:'สแกนหลายหน้า แก้ไขแบบไม่ทำลายต้นฉบับ ฟิลเตอร์ PDF, JPG และ PNG ในแอปมือถือ',private:'เป็นส่วนตัวตั้งแต่ต้น',privateBody:'ไม่มีบัญชี เซิร์ฟเวอร์ การวิเคราะห์เนื้อหา หรือการอัปโหลด คุณเลือกปลายทางของไฟล์เอง',review:'ตรวจสอบก่อนเปิด',reviewBody:'ดูชื่อโฮสต์และข้อมูลทั้งหมด อนุญาตเฉพาะเว็บ อีเมล และโทรศัพท์',footer:'โอเพนซอร์ส • ไม่อัปโหลด • อังกฤษและไทย',detected:n=>`พบคิวอาร์ ${n} รายการ`,noQr:'ไม่พบคิวอาร์ ลองใช้ภาพที่ชัดขึ้นหรือครอบให้ใกล้โค้ด',unsupported:'เนื้อหานี้แสดงเป็นข้อความ แอปไม่สามารถเปิดได้',copied:'คัดลอกแล้ว',cameraDenied:'ใช้กล้องไม่ได้หรือไม่ได้รับอนุญาต โปรดเลือกรูปภาพแทน',notSupported:'เบราว์เซอร์นี้ยังอ่านคิวอาร์ในเครื่องไม่ได้ โปรดใช้ Chrome หรือ Edge รุ่นปัจจุบัน หรือติดตั้งแอปมือถือ',ready:'การอ่านคิวอาร์ทำในเครื่องบนเบราว์เซอร์ที่รองรับ รูปภาพและข้อมูลจะไม่ออกจากอุปกรณ์นี้'}
};

let language = localStorage.getItem('language') || (navigator.language.startsWith('th') ? 'th' : 'en');
let detector, stream, frameTimer, results = [];
const $ = id => document.getElementById(id);
const {allowedAction} = ScanOpenLinkPolicy;

function applyLanguage() {
  document.documentElement.lang = language;
  document.querySelectorAll('[data-i18n]').forEach(node => {
    const value = translations[language][node.dataset.i18n];
    if (value) node.innerHTML = value;
  });
  $('language').textContent = language === 'en' ? 'ไทย' : 'EN';
  $('language').ariaLabel = language === 'en' ? 'เปลี่ยนเป็นภาษาไทย' : 'Switch to English';
  updateCompatibility();
  if (results.length) showResults(results, Number($('resultPicker').value || 0));
}

function setTheme(dark) {
  document.documentElement.classList.toggle('dark', dark);
  localStorage.setItem('theme', dark ? 'dark' : 'light');
  $('theme').ariaLabel = dark ? 'Use light theme' : 'Use dark theme';
}

function updateCompatibility(message) {
  $('compatibility').textContent = message || translations[language][('BarcodeDetector' in window) ? 'ready' : 'notSupported'];
  $('cameraButton').disabled = !('BarcodeDetector' in window);
}

async function getDetector() {
  if (!('BarcodeDetector' in window)) throw new Error('unsupported');
  if (!detector) detector = new BarcodeDetector({formats:['qr_code']});
  return detector;
}

async function decodeSource(source) {
  updateCompatibility(language === 'th' ? 'กำลังอ่าน…' : 'Reading…');
  try {
    const found = await (await getDetector()).detect(source);
    const unique = [...new Map(found.filter(item => item.rawValue).map(item => [item.rawValue, item])).values()];
    if (!unique.length) { clearResult(); updateCompatibility(translations[language].noQr); return; }
    results = unique.map(item => item.rawValue);
    showResults(results, 0);
    updateCompatibility();
  } catch (error) {
    clearResult();
    updateCompatibility(error.message === 'unsupported' ? translations[language].notSupported : translations[language].noQr);
  }
}

function showResults(values, selected) {
  results = values; $('emptyResult').hidden = true; $('resultContent').hidden = false;
  $('resultCount').textContent = translations[language].detected(values.length);
  const picker = $('resultPicker'); picker.replaceChildren(...values.map((value,index) => new Option(`${index+1}. ${value}`,index)));
  picker.value = String(selected); picker.hidden = values.length < 2; $('resultPickerLabel').hidden = values.length < 2;
  const payload = values[selected]; const action = allowedAction(payload);
  $('payload').textContent = payload; $('hostname').textContent = action?.host || (language === 'th' ? 'ข้อความ' : 'Text content');
  $('warning').textContent = action ? '' : translations[language].unsupported;
  $('openResult').hidden = !action; $('openResult').dataset.url = action?.url.href || '';
}

function clearResult() { results=[]; $('emptyResult').hidden=false; $('resultContent').hidden=true; }

async function readFile(file) {
  if (!file || !file.type.startsWith('image/') || file.size > 100 * 1024 * 1024) { updateCompatibility(translations[language].noQr); return; }
  const bitmap = await createImageBitmap(file); try { await decodeSource(bitmap); } finally { bitmap.close(); }
}

async function startCamera() {
  try {
    await getDetector();
    stream = await navigator.mediaDevices.getUserMedia({video:{facingMode:{ideal:'environment'}},audio:false});
    $('video').srcObject=stream; await $('video').play(); $('cameraPanel').hidden=false; $('cameraButton').hidden=true;
    const scan = async () => { if (!stream) return; try { const found=await detector.detect($('video')); if(found.length){const unique=[...new Set(found.map(x=>x.rawValue).filter(Boolean))];if(unique.length){showResults(unique,0);stopCamera();return;}} } catch {} frameTimer=setTimeout(scan,350); };
    scan();
  } catch { updateCompatibility(translations[language].cameraDenied); stopCamera(); }
}

function stopCamera(){clearTimeout(frameTimer);stream?.getTracks().forEach(track=>track.stop());stream=null;$('video').srcObject=null;$('cameraPanel').hidden=true;$('cameraButton').hidden=false;}

$('language').addEventListener('click',()=>{language=language==='en'?'th':'en';localStorage.setItem('language',language);applyLanguage();});
$('theme').addEventListener('click',()=>setTheme(!document.documentElement.classList.contains('dark')));
$('imageInput').addEventListener('change',event=>readFile(event.target.files[0]));
$('resultPicker').addEventListener('change',event=>showResults(results,Number(event.target.value)));
$('cameraButton').addEventListener('click',startCamera); $('stopCamera').addEventListener('click',stopCamera);
$('openResult').addEventListener('click',event=>window.open(event.currentTarget.dataset.url,'_blank','noopener,noreferrer'));
$('copyResult').addEventListener('click',async()=>{await navigator.clipboard.writeText($('payload').textContent);updateCompatibility(translations[language].copied);});
$('shareResult').addEventListener('click',async()=>{const text=$('payload').textContent;if(navigator.share)await navigator.share({text});else await navigator.clipboard.writeText(text);});
['dragenter','dragover'].forEach(name=>$('dropZone').addEventListener(name,event=>{event.preventDefault();$('dropZone').classList.add('drag');}));
['dragleave','drop'].forEach(name=>$('dropZone').addEventListener(name,event=>{event.preventDefault();$('dropZone').classList.remove('drag');}));
$('dropZone').addEventListener('drop',event=>readFile(event.dataTransfer.files[0]));
window.addEventListener('pagehide',stopCamera);

const storedTheme=localStorage.getItem('theme');setTheme(storedTheme?storedTheme==='dark':matchMedia('(prefers-color-scheme: dark)').matches);applyLanguage();
if('serviceWorker' in navigator) navigator.serviceWorker.register('service-worker.js',{scope:'./'});
