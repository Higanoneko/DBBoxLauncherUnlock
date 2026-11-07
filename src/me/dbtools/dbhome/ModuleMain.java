package me.dbtools.dbhome;

import android.util.Log;

import androidx.annotation.NonNull;

import java.lang.reflect.Method;

import io.github.libxposed.api.XposedModule;

/**
 * 解除当贝盒子 (rk356x / Dangbei OS, Android 11) 的"桌面包名白名单"。
 *
 * 原理：system_server 里的 PackageManagerService.isNotDangbeiLauncher(String)
 * 会检查包名是否在 DANGBEI_LAUNCHERS / DANGBEI_CHILD_LAUNCHERS 名单内；
 * 不在名单 → 返回 true → applyPostResolutionFilter() 把该 ResolveInfo 从
 * HOME intent 解析结果中 remove 掉，于是第三方桌面连候选都进不去。
 *
 * 本模块把 isNotDangbeiLauncher 恒改为返回 false，放开全部桌面。
 */
public class ModuleMain extends XposedModule {
    private static final String TAG = "[DBHomeUnlock]";
    private static final String PMS = "com.android.server.pm.PackageManagerService";

    private void installHook(ClassLoader cl, String where) {
        // 直接写 logcat（android.util.Log），不依赖 lspd 的 log() 转发——即使 lspd logd 崩溃也能看到
        Log.i(TAG, "installHook via " + where);
        log(Log.INFO, TAG, "installHook via " + where);
        try {
            Class<?> pms = cl.loadClass(PMS);
            Method m = pms.getDeclaredMethod("isNotDangbeiLauncher", String.class);
            m.setAccessible(true);
            hook(m).intercept(chain -> Boolean.FALSE);
            Log.i(TAG, "hooked isNotDangbeiLauncher OK");
            log(Log.INFO, TAG, "hooked isNotDangbeiLauncher OK");
        } catch (Throwable t) {
            Log.e(TAG, "hook failed", t);
            log(Log.ERROR, TAG, "hook failed", t);
        }
    }

    // 模块被加载进进程时一定会调——先打一条证明我们活没活
    @Override
    public void onModuleLoaded(@NonNull ModuleLoadedParam param) {
        try {
            Log.i(TAG, "onModuleLoaded: process=" + param.getProcessName()
                    + " isSystemServer=" + param.isSystemServer());
        } catch (Throwable ignored) { }
    }

    // system_server: 首包回调被替换为 onSystemServerStarting
    @Override
    public void onSystemServerStarting(@NonNull SystemServerStartingParam param) {
        Log.i(TAG, "onSystemServerStarting: cl=" + param.getClassLoader());
        installHook(param.getClassLoader(), "onSystemServerStarting");
    }

    // 所有 app 加载都会回调——先不过滤，全量打出来看 system_server 走不走这
    @Override
    public void onPackageLoaded(@NonNull PackageLoadedParam param) {
        String pkg = param.getPackageName();
        Log.i(TAG, "onPackageLoaded: " + pkg + " isFirst=" + param.isFirstPackage());
        if ("android".equals(pkg)) {
            installHook(param.getDefaultClassLoader(), "onPackageLoaded");
        }
    }
}
