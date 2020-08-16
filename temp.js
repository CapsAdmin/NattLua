
globalThis.print = console.log;
globalThis.arg = []

globalThis.math = {}
globalThis.math.sqrt = Math.sqrt


globalThis.io = {}
globalThis.io.write = console.log

let metatables = new Map()

globalThis.table = {}
table.insert = (tbl, i, val) => {
    if (!val) {
        val = i
    }

    tbl.push(val)
}

globalThis.setmetatable = (obj, meta) => {
    metatables.set(obj, meta)
    return obj
}
globalThis.getmetatable = (obj) => {
    return metatables.get(obj)
}

let nil = undefined

let OP = {}
{
    OP["="] = (obj, key, val) => {
        obj[key] = val
    }

    OP["."] = (l, r) => {
        if (l[r]) {
            return l[r]
        }

        let lmeta = getmetatable(l)
        
        if (lmeta && lmeta.__index) {
            if (lmeta.__index === lmeta) {
                return lmeta[r]
            }

            return lmeta.__index(l, r)
        }

        return nil
    }

    let self = undefined

                OP["<<"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__lshift) {
                    return lmeta.__lshift(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__lshift) {
                    return rmeta.__lshift(l, r)
                }
        
                return l << r
            }
                    OP["-"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__sub) {
                    return lmeta.__sub(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__sub) {
                    return rmeta.__sub(l, r)
                }
        
                return l - r
            }
                    OP["|"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__bor) {
                    return lmeta.__bor(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__bor) {
                    return rmeta.__bor(l, r)
                }
        
                return l | r
            }
                    OP["+"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__add) {
                    return lmeta.__add(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__add) {
                    return rmeta.__add(l, r)
                }
        
                return l + r
            }
                    OP["/"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__div) {
                    return lmeta.__div(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__div) {
                    return rmeta.__div(l, r)
                }
        
                return l / r
            }
                    OP["*"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__mul) {
                    return lmeta.__mul(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__mul) {
                    return rmeta.__mul(l, r)
                }
        
                return l * r
            }
                    OP[">>"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__rshift) {
                    return lmeta.__rshift(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__rshift) {
                    return rmeta.__rshift(l, r)
                }
        
                return l >> r
            }
                    OP["%"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__mod) {
                    return lmeta.__mod(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__mod) {
                    return rmeta.__mod(l, r)
                }
        
                return l % r
            }
                    OP["/idiv/"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__idiv) {
                    return lmeta.__idiv(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__idiv) {
                    return rmeta.__idiv(l, r)
                }
        
                return l /idiv/ r
            }
                    OP["&"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__band) {
                    return lmeta.__band(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__band) {
                    return rmeta.__band(l, r)
                }
        
                return l & r
            }
                    OP["^"] = (l,r) => {
                let lmeta = getmetatable(l)
                if (lmeta && lmeta.__pow) {
                    return lmeta.__pow(l, r)
                }
        
                let rmeta = getmetatable(r)
        
                if (rmeta && rmeta.__pow) {
                    return rmeta.__pow(l, r)
                }
        
                return l ^ r
            }
        

    OP["and"] = (l, r) => l !== undefined && l !== false && r !== undefined && r !== false
    OP["or"] = (l, r) => l !== undefined && l !== false || r !== undefined && r !== false

    OP[":"] = (l, r) => {
        self = l
        return OP["."](l,r)
    }

    OP["call"] = (obj, ...args) => {
        if (!obj) {
            throw "attempt to call a nil value"
        }
        if (self) {
            let a = self
            self = undefined
            return obj.apply(obj, [a, ...args])
        }

        return obj.apply(obj, args)
    }
}
globalThis.sun= {};
globalThis.jupiter= {};
globalThis.saturn= {};
globalThis.uranus= {};
globalThis.neptune= {};

let sqrt = OP['.'](globalThis.math,'sqrt');

let PI = 3.141592653589793;
let SOLAR_MASS = OP['*']( OP['*'](4, PI), PI);
let DAYS_PER_YEAR = 365.24;OP['='](
globalThis.sun,'x', 0.0);;OP['='](
globalThis.sun,'y', 0.0);;OP['='](
globalThis.sun,'z', 0.0);;OP['='](
globalThis.sun,'vx', 0.0);;OP['='](
globalThis.sun,'vy', 0.0);;OP['='](
globalThis.sun,'vz', 0.0);;OP['='](
globalThis.sun,'mass', SOLAR_MASS);;OP['='](
globalThis.jupiter,'x', 4.84143144246472090e+00);;OP['='](
globalThis.jupiter,'y', -1.16032004402742839e+00);;OP['='](
globalThis.jupiter,'z', -1.03622044471123109e-01);;OP['='](
globalThis.jupiter,'vx', OP['*'](1.66007664274403694e-03, DAYS_PER_YEAR));;OP['='](
globalThis.jupiter,'vy', OP['*'](7.69901118419740425e-03, DAYS_PER_YEAR));;OP['='](
globalThis.jupiter,'vz', OP['*'](-6.90460016972063023e-05, DAYS_PER_YEAR));;OP['='](
globalThis.jupiter,'mass', OP['*'](9.54791938424326609e-04, SOLAR_MASS));;OP['='](
globalThis.saturn,'x', 8.34336671824457987e+00);;OP['='](
globalThis.saturn,'y', 4.12479856412430479e+00);;OP['='](
globalThis.saturn,'z', -4.03523417114321381e-01);;OP['='](
globalThis.saturn,'vx', OP['*'](-2.76742510726862411e-03, DAYS_PER_YEAR));;OP['='](
globalThis.saturn,'vy', OP['*'](4.99852801234917238e-03, DAYS_PER_YEAR));;OP['='](
globalThis.saturn,'vz', OP['*'](2.30417297573763929e-05, DAYS_PER_YEAR));;OP['='](
globalThis.saturn,'mass', OP['*'](2.85885980666130812e-04, SOLAR_MASS));;OP['='](
globalThis.uranus,'x', 1.28943695621391310e+01);;OP['='](
globalThis.uranus,'y', -1.51111514016986312e+01);;OP['='](
globalThis.uranus,'z', -2.23307578892655734e-01);;OP['='](
globalThis.uranus,'vx', OP['*'](2.96460137564761618e-03, DAYS_PER_YEAR));;OP['='](
globalThis.uranus,'vy', OP['*'](2.37847173959480950e-03, DAYS_PER_YEAR));;OP['='](
globalThis.uranus,'vz', OP['*'](-2.96589568540237556e-05, DAYS_PER_YEAR));;OP['='](
globalThis.uranus,'mass', OP['*'](4.36624404335156298e-05, SOLAR_MASS));;OP['='](
globalThis.neptune,'x', 1.53796971148509165e+01);;OP['='](
globalThis.neptune,'y', -2.59193146099879641e+01);;OP['='](
globalThis.neptune,'z', 1.79258772950371181e-01);;OP['='](
globalThis.neptune,'vx', OP['*'](2.68067772490389322e-03, DAYS_PER_YEAR));;OP['='](
globalThis.neptune,'vy', OP['*'](1.62824170038242295e-03, DAYS_PER_YEAR));;OP['='](
globalThis.neptune,'vz', OP['*'](-9.51592254519715870e-05, DAYS_PER_YEAR));;OP['='](
globalThis.neptune,'mass', OP['*'](5.15138902046611451e-05, SOLAR_MASS));;

let bodies = [globalThis.sun,globalThis.jupiter,globalThis.saturn,globalThis.uranus,globalThis.neptune]; 

let advance; advance=(bodies, nbody, dt) => {
  for(let i=1; i<=nbody; i++) {
    let bi = bodies[i];
    let bix = OP['.'](bi,'x'), biy = OP['.'](bi,'y'), biz = OP['.'](bi,'z'), bimass = OP['.'](bi,'mass');
    let bivx = OP['.'](bi,'vx'), bivy = OP['.'](bi,'vy'), bivz = OP['.'](bi,'vz');
    for(let j=OP['+'](i,1); j<=nbody; j++) {
      let bj = bodies[j];
      let dx = OP['-'](bix,OP['.'](bj,'x')), dy = OP['-'](biy,OP['.'](bj,'y')), dz = OP['-'](biz,OP['.'](bj,'z'));
      let dist2 = OP['+'](OP['+']( OP['*'](dx,dx), OP['*'](dy,dy)), OP['*'](dz,dz));
      let mag =OP['call']( sqrt,dist2);
      mag= OP['/'](dt, (OP['*'](mag, dist2)));
      let bm =OP['*']( OP['.'](bj,'mass'),mag);
      bivx= OP['-'](bivx, (OP['*'](dx, bm)));
      bivy= OP['-'](bivy, (OP['*'](dy, bm)));
      bivz= OP['-'](bivz, (OP['*'](dz, bm)));
      bm= OP['*'](bimass,mag);OP['='](
      bj,'vx',OP['+']( OP['.'](bj,'vx'), (OP['*'](dx, bm))));;OP['='](
      bj,'vy',OP['+']( OP['.'](bj,'vy'), (OP['*'](dy, bm))));;OP['='](
      bj,'vz',OP['+']( OP['.'](bj,'vz'), (OP['*'](dz, bm))));;
    };OP['='](
    bi,'vx', bivx);;OP['='](
    bi,'vy', bivy);;OP['='](
    bi,'vz', bivz);;OP['='](
    bi,'x', OP['+'](bix, OP['*'](dt, bivx)));;OP['='](
    bi,'y', OP['+'](biy, OP['*'](dt, bivy)));;OP['='](
    bi,'z', OP['+'](biz, OP['*'](dt, bivz)));;
  };
}; 

let energy; energy=(bodies, nbody) => {
  let e = 0;
  for(let i=1; i<=nbody; i++) {
    let bi = bodies[i];
    let vx = OP['.'](bi,'vx'), vy = OP['.'](bi,'vy'), vz = OP['.'](bi,'vz'), bim = OP['.'](bi,'mass');
    e= OP['+'](e, ( OP['*'](OP['*'](0.5, bim), ( OP['+'](OP['+'](OP['*'](vx,vx), OP['*'](vy,vy)), OP['*'](vz,vz))))));
    for(let j=OP['+'](i,1); j<=nbody; j++) {
      let bj = bodies[j];
      let dx =OP['-']( OP['.'](bi,'x'),OP['.'](bj,'x')), dy =OP['-']( OP['.'](bi,'y'),OP['.'](bj,'y')), dz =OP['-']( OP['.'](bi,'z'),OP['.'](bj,'z'));
      let distance =OP['call']( sqrt, OP['+'](OP['+'](OP['*'](dx,dx), OP['*'](dy,dy)), OP['*'](dz,dz)));
      e= OP['-'](e, ( OP['/']((OP['*'](bim, OP['.'](bj,'mass'))), distance)));
    };
  };
  return e;
}; 

let offsetMomentum; offsetMomentum=(b, nbody) => {
  let px = 0, py = 0, pz = 0;
  for(let i=1; i<=nbody; i++) {
    let bi = b[i];
    let bim = OP['.'](bi,'mass');
    px= OP['+'](px, (OP['*'](OP['.'](bi,'vx'), bim)));
    py= OP['+'](py, (OP['*'](OP['.'](bi,'vy'), bim)));
    pz= OP['+'](pz, (OP['*'](OP['.'](bi,'vz'), bim)));
  };OP['='](
  b[1],'vx', OP['/'](-px, SOLAR_MASS));;OP['='](
  b[1],'vy', OP['/'](-py, SOLAR_MASS));;OP['='](
  b[1],'vz', OP['/'](-pz, SOLAR_MASS));;
};

let N =OP['or'](OP['call']( globalThis.tonumber,OP['and'](globalThis.arg, globalThis.arg[1])), 1000);
let nbody =OP['#'](bodies);OP['call'](

offsetMomentum,bodies, nbody);OP['call'](
OP['.'](globalThis.io,'write'),OP['call']( OP['.'](globalThis.string,'format'),"%0.9f",OP['call'](energy,bodies, nbody)), "\n");
for(let i=1; i<=N; i++) {OP['call']( advance,bodies, nbody, 0.01); };OP['call'](
OP['.'](globalThis.io,'write'),OP['call']( OP['.'](globalThis.string,'format'),"%0.9f",OP['call'](energy,bodies, nbody)), "\n");
;