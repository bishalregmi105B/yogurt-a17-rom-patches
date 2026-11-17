//
// Copyright (C) 2026 The DerpFest Project (yogurt single-slot recovery build)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#ifndef UPDATE_ENGINE_AOSP_BOOT_CONTROL_RECOVERY_H_
#define UPDATE_ENGINE_AOSP_BOOT_CONTROL_RECOVERY_H_

#include <memory>
#include <optional>
#include <string>

#include <android-base/macros.h>
#include <base/callback.h>

#include "update_engine/aosp/dynamic_partition_control_android.h"
#include "update_engine/common/boot_control_interface.h"
#include "update_engine/common/dynamic_partition_control_interface.h"

namespace chromeos_update_engine {

// Single-slot, HAL-free implementation of BootControlInterface for non-A/B
// ("half-A/B" MTK) devices: the recovery ramdisk has no IBootControl HAL
// service, and the bootloader has no slot metadata (misc is all zeros).
// The device is treated as having exactly one slot (0); all slot-flag
// operations are no-ops. Partition device lookup is delegated to
// DynamicPartitionControlAndroid, which maps the unsuffixed logical
// partitions in super (system/vendor/product) itself.
//
// Build note: this class is only linked into the recovery flavour of the
// engine (update_engine_sideload), where UE_NON_AB_RECOVERY is defined; the
// in-system daemon keeps using BootControlAndroid + the boot-control HAL.
class BootControlRecovery final : public BootControlInterface {
 public:
  BootControlRecovery() = default;
  ~BootControlRecovery() = default;

  // Constructs DynamicPartitionControlAndroid; never fails.
  bool Init();

  // BootControlInterface overrides.
  unsigned int GetNumSlots() const override;
  BootControlInterface::Slot GetCurrentSlot() const override;
  bool GetPartitionDevice(const std::string& partition_name,
                          BootControlInterface::Slot slot,
                          bool not_in_payload,
                          std::string* device,
                          bool* is_dynamic) const override;
  bool GetPartitionDevice(const std::string& partition_name,
                          BootControlInterface::Slot slot,
                          std::string* device) const override;
  std::optional<PartitionDevice> GetPartitionDevice(
      const std::string& partition_name,
      uint32_t slot,
      uint32_t current_slot,
      bool not_in_payload = false) const override;
  bool IsSlotBootable(BootControlInterface::Slot slot) const override;
  bool MarkSlotUnbootable(BootControlInterface::Slot slot) override;
  bool SetActiveBootSlot(BootControlInterface::Slot slot) override;
  bool MarkBootSuccessfulAsync(base::Callback<void(bool)> callback) override;
  bool IsSlotMarkedSuccessful(BootControlInterface::Slot slot) const override;
  BootControlInterface::Slot GetActiveBootSlot() override;
  DynamicPartitionControlInterface* GetDynamicPartitionControl() override;

 private:
  std::unique_ptr<DynamicPartitionControlAndroid> dynamic_control_;

  DISALLOW_COPY_AND_ASSIGN(BootControlRecovery);
};

}  // namespace chromeos_update_engine

#endif  // UPDATE_ENGINE_AOSP_BOOT_CONTROL_RECOVERY_H_
