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

// Recovery flavour ONLY. In the recovery ramdisk there is no IBootControl
// HAL service (and the bootloader keeps no slot metadata on this device), so
// update_engine_sideload is built with -DUE_NON_AB_RECOVERY to provide a
// single-slot BootControlRecovery that needs no HAL. In the daemon flavour
// this TU compiles to nothing, and BootControlAndroid keeps serving the
// HAL-based implementation.

#ifdef UE_NON_AB_RECOVERY

#include "update_engine/aosp/boot_control_recovery.h"

#include <utility>

namespace chromeos_update_engine {

using Slot = BootControlInterface::Slot;

namespace boot_control {

// Factory declared in update_engine/aosp/boot_control.h. The recovery
// flavour of the engine picks this over BootControlAndroid.
std::unique_ptr<BootControlInterface> CreateBootControl() {
  auto boot_control = std::make_unique<BootControlRecovery>();
  if (!boot_control->Init()) {
    return nullptr;
  }
  return std::move(boot_control);
}

}  // namespace boot_control

bool BootControlRecovery::Init() {
  dynamic_control_ =
      std::make_unique<DynamicPartitionControlAndroid>(GetCurrentSlot());
  return true;
}

unsigned int BootControlRecovery::GetNumSlots() const {
  return 1;
}

BootControlInterface::Slot BootControlRecovery::GetCurrentSlot() const {
  return 0;
}

std::optional<PartitionDevice> BootControlRecovery::GetPartitionDevice(
    const std::string& partition_name,
    uint32_t slot,
    uint32_t current_slot,
    bool not_in_payload) const {
  return dynamic_control_->GetPartitionDevice(
      partition_name, slot, current_slot, not_in_payload);
}

bool BootControlRecovery::GetPartitionDevice(const std::string& partition_name,
                                             Slot slot,
                                             bool not_in_payload,
                                             std::string* device,
                                             bool* is_dynamic) const {
  auto partition_dev = dynamic_control_->GetPartitionDevice(
      partition_name, slot, GetCurrentSlot(), not_in_payload);
  if (!partition_dev.has_value()) {
    return false;
  }
  if (device) {
    *device = std::move(partition_dev->rw_device_path);
  }
  if (is_dynamic) {
    *is_dynamic = partition_dev->is_dynamic;
  }
  return true;
}

bool BootControlRecovery::GetPartitionDevice(const std::string& partition_name,
                                             Slot slot,
                                             std::string* device) const {
  return GetPartitionDevice(
      partition_name, slot, false /* not_in_payload */, device, nullptr);
}

bool BootControlRecovery::IsSlotBootable(Slot /*slot*/) const {
  // Single slot: always bootable.
  return true;
}

bool BootControlRecovery::MarkSlotUnbootable(Slot /*slot*/) {
  // Single slot: nothing to mark.
  return true;
}

bool BootControlRecovery::SetActiveBootSlot(Slot /*slot*/) {
  // Single slot: no slot switching to perform.
  return true;
}

Slot BootControlRecovery::GetActiveBootSlot() {
  return 0;
}

bool BootControlRecovery::MarkBootSuccessfulAsync(
    base::Callback<void(bool)> callback) {
  // Single slot: report success to the caller immediately.
  callback.Run(true);
  return true;
}

bool BootControlRecovery::IsSlotMarkedSuccessful(Slot /*slot*/) const {
  // Single slot: always considered successful.
  return true;
}

DynamicPartitionControlInterface*
BootControlRecovery::GetDynamicPartitionControl() {
  return dynamic_control_.get();
}

}  // namespace chromeos_update_engine

#endif  // UE_NON_AB_RECOVERY
