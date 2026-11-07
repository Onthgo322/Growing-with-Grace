// Scheduled weekly billing. Runs in America/Chicago on Fridays via GitHub Actions.
// Requires SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY and BILLING_USER_ID secrets.
// Deliberately refuses to charge unless billing is explicitly enabled for a child.
const url=process.env.SUPABASE_URL,key=process.env.SUPABASE_SERVICE_ROLE_KEY,owner=process.env.BILLING_USER_ID;
const dryRun=process.env.BILLING_DRY_RUN!=='false';
if(!url||!key||!owner)throw Error('Missing required billing secrets; no charges created');
const headers={apikey:key,Authorization:'Bearer '+key,'Content-Type':'application/json'};
async function query(table,params=''){const r=await fetch(url+'/rest/v1/'+table+'?'+params,{headers});if(!r.ok)throw Error(table+' read failed '+r.status+': '+await r.text());return r.json();}
const chicago=new Intl.DateTimeFormat('en-CA',{timeZone:'America/Chicago',year:'numeric',month:'2-digit',day:'2-digit',weekday:'short'});
const parts=Object.fromEntries(chicago.formatToParts(new Date()).map(x=>[x.type,x.value]));
if(parts.weekday!=='Fri') {console.log('Not Friday in Chicago; skipped');process.exit(0);}
const iso=[parts.year,parts.month,parts.day].join('-');
const shift=(s,n)=>{const d=new Date(s+'T12:00:00Z');d.setUTCDate(d.getUTCDate()+n);return d.toISOString().slice(0,10);};
const weekStart=shift(iso,3),weekEnd=shift(iso,7);
const [children,rates,existing]=await Promise.all([
 query('daycare_children','select=*&user_id=eq.'+encodeURIComponent(owner)),
 query('daycare_rates','select=*&user_id=eq.'+encodeURIComponent(owner)),
 query('daycare_transactions','select=child_id,entry_type,category,week_start,week_end&user_id=eq.'+encodeURIComponent(owner)+'&week_start=eq.'+weekStart)
]);
function ageOn(birth,date){let y=+date.slice(0,4)- +birth.slice(0,4);if(date.slice(5)<birth.slice(5))y--;return y;}
function category(c){if(!c.date_of_birth||c.rate_category==='Before/After School Care')return c.rate_category;
// Rate changes only after birthday week. Age as of Monday sets the rate for the whole week.
const age=ageOn(c.date_of_birth,weekStart);
return age<2?'Infant':age<3?'2-Year':age<4?'3-Year':age<5?'4-Year':'5–12 Years';
}
const candidates=[];
const skipped=[];
function childLabel(c){return c.name||[c.first_name,c.last_name].filter(Boolean).join(' ')||String(c.id);}
function skip(c,reason){skipped.push({name:childLabel(c),reason});}
for(const c of children){
 if(c.auto_weekly_billing!==true)continue;
 if(c.receives_ccap===true){skip(c,'CCAP enabled');continue;}
 if(c.child_status!=='Active'){skip(c,'Status: '+String(c.child_status));continue;}
 if(c.last_day_of_care&&c.last_day_of_care<weekStart){skip(c,'Last day of care before billing week: '+c.last_day_of_care);continue;}
 if(c.last_day_of_care&&c.last_day_of_care<weekEnd){skip(c,'Partial week ending '+c.last_day_of_care+' requires review');continue;}
 if(existing.some(t=>t.child_id===c.id&&t.entry_type==='Charge'&&String(t.category||'').toUpperCase()!=='CCAP')){skip(c,'Already has a charge for billing week');continue;}
 const cat=category(c);
 const rate=rates.filter(r=>r.category===cat&&r.effective_date<=weekEnd).sort((a,b)=>b.effective_date.localeCompare(a.effective_date))[0];
 const amount=c.rate_type==='fixed'?Number(c.fixed_weekly_rate):rate?Number(rate.school_day)*(1-Number(c.employee_discount_percent||0)/100):NaN;
 if(!Number.isFinite(amount)||amount<=0){skip(c,'Missing or invalid rate for '+String(cat));continue;}
 candidates.push({user_id:owner,child_id:c.id,week_start:weekStart,week_end:weekEnd,entry_date:iso,entry_type:'Charge',category:'Regular daycare',payment_method:null,amount:Math.round(amount*100)/100,notes:''});
}
console.log('Friday '+iso+': '+candidates.length+' eligible weekly charges');
console.log('Auto billing checked: '+children.filter(c=>c.auto_weekly_billing===true).length);
for(const row of candidates){const c=children.find(c=>c.id===row.child_id);console.log('ELIGIBLE: '+childLabel(c)+' | amount: '+row.amount.toFixed(2)+' | '+weekStart+' to '+weekEnd);}
for(const item of skipped)console.log('SKIPPED: '+item.name+' | '+item.reason);
if(dryRun){console.log('DRY RUN ONLY: no charges will be saved. Eligible count: '+candidates.length);process.exit(0);}
if(!candidates.length)process.exit(0);
// Recheck each row immediately before insertion. A database uniqueness constraint is still recommended for concurrency safety.
for(const row of candidates){
 const found=await query('daycare_transactions','select=id&user_id=eq.'+encodeURIComponent(owner)+'&child_id=eq.'+row.child_id+'&entry_type=eq.Charge&week_start=eq.'+weekStart+'&week_end=eq.'+weekEnd);
 if(found.length){console.log('Skipped already charged '+row.child_id);continue;}
 const r=await fetch(url+'/rest/v1/daycare_transactions',{method:'POST',headers:{...headers,Prefer:'return=minimal'},body:JSON.stringify(row)});
 if(!r.ok)throw Error('Charge save failed for '+row.child_id+': '+r.status+' '+await r.text());
 console.log('Saved weekly charge for '+row.child_id);
}
