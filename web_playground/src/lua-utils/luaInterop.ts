export interface LuaInterop {
  newState: () => void;
  doString: (s: string, ...any) => any;
  L: any;
  lib: any;
  push_js: (L: any, jsValue: any, isArrow?: boolean) => number;
  lua_to_js: (L: any, i: number) => any;
  luaopen_js: () => void;
  [key: string]: any;
}

export type NewLuaFunc = (args?: Record<string, any>) => Promise<LuaInterop>;

let newLuaPromise: Promise<{ newLua: NewLuaFunc }> | null = null;

export async function getLuaInterop(): Promise<{ newLua: NewLuaFunc }> {
  if (!newLuaPromise) {
    newLuaPromise = new Promise((resolve, reject) => {
      const script = document.createElement('script');
      script.src = '/js/lua-interop.js';
      script.type = 'module';

      script.onload = () => {
        if (window.newLua) {
          resolve({ newLua: window.newLua });
        } else {
          import('/js/lua-interop.js' as string)
            .then(module => {
              resolve(module);
            })
            .catch(error => {
              reject(new Error(`Failed to import lua-interop.js: ${error.message}`));
            });
        }
      };

      script.onerror = () => {
        reject(new Error('Failed to load lua-interop.js'));
      };

      document.head.appendChild(script);
    });
  }

  return newLuaPromise;
}

declare global {
  interface Window {
    newLua?: NewLuaFunc;
  }
}
