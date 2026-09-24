const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
let rtlMode = 'small';

function show(view) { $$('.view').forEach(v => v.classList.toggle('active', v.id === view)); $$('.nav').forEach(n => n.classList.toggle('active', n.dataset.view === view)); }
$$('.nav,.jump').forEach(el => el.addEventListener('click', () => show(el.dataset.view)));
async function post(url, body) { const r = await fetch(url, {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)}); const result = await r.json(); if (!r.ok) throw new Error(result.error || `请求失败 (${r.status})`); return result; }
function printResult(target, result) { $(target).textContent = [result.ok ? '完成' : '失败', `耗时 ${result.seconds}s`, result.stdout || '', result.stderr || ''].filter(Boolean).join('\n'); }

fetch('/api/health').then(r=>r.json()).then(x=>{ $('#health').textContent = x.ok ? '本地服务在线' : '服务异常'; }).catch(()=>$('#health').textContent='服务离线');
$('#python-form').addEventListener('submit', async (e) => { e.preventDefault(); const data = Object.fromEntries(new FormData(e.currentTarget)); $('#python-log').textContent='运行中…'; $('#python-files').innerHTML=''; try { const result = await post('/api/python-sim', data); printResult('#python-log', result); (result.files||[]).forEach(f=>{const a=document.createElement('a');a.className='file-link';a.href=f.url;a.textContent=f.name;a.download=f.name;$('#python-files').append(a)}); $('#python-time').textContent=`${result.seconds||0}s`; } catch (error) { $('#python-log').textContent=`失败\n${error.message}`; $('#python-time').textContent='请求失败'; } });
$$('.mode').forEach(el=>el.addEventListener('click',()=>{$$('.mode').forEach(x=>x.classList.remove('active'));el.classList.add('active');rtlMode=el.dataset.mode;}));
$('#rtl-run').addEventListener('click', async () => { $('#rtl-log').textContent='编译并运行中…'; try { const result=await post('/api/rtl-sim',{mode:rtlMode}); printResult('#rtl-log',result); $('#rtl-time').textContent=`${result.seconds||0}s`; } catch (error) { $('#rtl-log').textContent=`失败\n${error.message}`; $('#rtl-time').textContent='请求失败'; } });
$('#board-form').addEventListener('submit', async (e)=>{e.preventDefault(); try { const result=await post('/api/board-config',Object.fromEntries(new FormData(e.currentTarget))); $('#board-log').textContent=`配置已保存\n${JSON.stringify(result.config,null,2)}\n\n文件：${result.path}`; } catch (error) { $('#board-log').textContent=`保存失败\n${error.message}`; }});
