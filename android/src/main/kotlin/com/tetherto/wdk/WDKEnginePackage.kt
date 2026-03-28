/**
 * WDKEnginePackage — React Native TurboModule Package Registration (RN 0.76+)
 *
 * Extends BaseReactPackage (the RN 0.76 recommended base class for
 * TurboModule packages) to provide the WDKEngineModule to the runtime.
 */

package com.tetherto.wdk

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider

class WDKEnginePackage : BaseReactPackage() {

    override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
        return if (name == WDKEngineModule.NAME) {
            WDKEngineModule(reactContext)
        } else {
            null
        }
    }

    override fun getReactModuleInfoProvider(): ReactModuleInfoProvider {
        return ReactModuleInfoProvider {
            mapOf(
                WDKEngineModule.NAME to ReactModuleInfo(
                    WDKEngineModule.NAME,       // name
                    WDKEngineModule.NAME,       // className
                    false,                       // canOverrideExistingModule
                    false,                       // needsEagerInit
                    false,                       // isCxxModule
                    true                         // isTurboModule
                )
            )
        }
    }
}
