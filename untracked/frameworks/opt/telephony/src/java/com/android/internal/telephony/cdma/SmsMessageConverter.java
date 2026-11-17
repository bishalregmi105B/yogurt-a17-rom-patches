/*
 * Copyright (C) 2017 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.android.internal.telephony.cdma;

import android.hardware.radio.V1_0.CdmaSmsMessage;
import android.telephony.SmsMessage;

import com.android.internal.telephony.RILUtils;

/**
 * Compatibility converter for vendor IMS/RIL stacks calling legacy SmsMessageConverter.
 */
public class SmsMessageConverter {
    public static SmsMessage newSmsMessageFromCdmaSmsMessage(CdmaSmsMessage cdmaSmsMessage) {
        return new SmsMessage(RILUtils.convertHalCdmaSmsMessage(cdmaSmsMessage));
    }
}
