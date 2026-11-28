// Usage: node probe-teardown-cancel.js <repo path>
const {LifecycleRegistry}=require(process.argv[2]+'/MiniProgram/index.js');
for (const mode of ['cancel-one','cancel-all']) {
  const r=LifecycleRegistry.of({}); let second, ret, ran=false;
  r.addDeallocCallback(()=>{ ret = mode==='cancel-one' ? r.cancelDeallocCallback({identifier:second}) : r.cancelAllDeallocCallbacks(); });
  second=r.addDeallocCallback(()=>{ran=true});
  r.runDealloc();
  console.log(mode,'return=',ret,'secondRan=',ran);
}
