// Usage: node probe-unload-midscroll.js <repo path>
const lib = require(process.argv[2]+'/MiniProgram/index.js');
const {LifecycleController, LifecycleCenter, withLifecycle} = lib;
let calls=[];
LifecycleCenter.whileUserScrolls(()=>calls.push('pause'),()=>calls.push('resume'));
const c = new LifecycleController({});
c.onLoad(); c.onPageScroll({}); c.onUnload();
setTimeout(()=>{ console.log('MP unload mid-scroll:', JSON.stringify(calls), 'isUserScrolling=', LifecycleCenter.isUserScrolling);
 const p = Object.assign({}, withLifecycle({})); p.onLoad(); console.log('withLifecycle sets cyl:', !!p.cyl, 'cylController:', !!p.cylController); },400);