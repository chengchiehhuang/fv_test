#!/bin/bash
set -ex

BUILD_DIR=build
DEST_DIR=testdata
EDK2_TOOLS=${BUILD_DIR}/edk2/BaseTools/BinWrappers/PosixLike

mkdir -p ${BUILD_DIR}

(
  cd ${BUILD_DIR}
  if [[ ! -d edk2 ]]; then
    git clone --recursive https://github.com/tianocore/edk2.git
  fi
  cd edk2
  make -C BaseTools
)

cat > ${BUILD_DIR}/fv_template.inf <<- "EOF"
[options]
EFI_BASE_ADDRESS = 0x800000
EFI_BLOCK_SIZE  = 0x1000
[attributes]
EFI_ERASE_POLARITY   =  1
EFI_ERASE_POLARITY = 1
EFI_MEMORY_MAPPED = TRUE
EFI_STICKY_WRITE = TRUE
EFI_LOCK_CAP = TRUE
EFI_LOCK_STATUS = TRUE
EFI_WRITE_DISABLED_CAP = TRUE
EFI_WRITE_ENABLED_CAP = TRUE
EFI_WRITE_STATUS = TRUE
EFI_WRITE_LOCK_CAP = TRUE
EFI_WRITE_LOCK_STATUS = TRUE
EFI_READ_DISABLED_CAP = TRUE
EFI_READ_ENABLED_CAP = TRUE
EFI_READ_STATUS = TRUE
EFI_READ_LOCK_CAP = TRUE
EFI_READ_LOCK_STATUS = TRUE
EFI_FVB2_ALIGNMENT_16 = TRUE
EFI_FV_EXT_HEADER_FILE_NAME = samples/PLDFV.ext
[files]
EOF

cat > ${BUILD_DIR}/drivers.inf <<- "EOF"
EFI_FILE_NAME = samples/ffs/80CF7257-87AB-47f9-A3FE-D50B76D89541.ffs
EFI_FILE_NAME = samples/ffs/9B680FCE-AD6B-4F3A-B60B-F59899003443.ffs
EFI_FILE_NAME = samples/ffs/F099D67F-71AE-4c36-B2A3-DCEB0EB2B7D8.ffs
EOF

gen_fv() {
  ${EDK2_TOOLS}/GenFv -F FALSE -i $1 -o $2
}

gen_sec() {
  ${EDK2_TOOLS}/GenSec $2 -s $1 -o $3
}

gen_ffs_from_sec() {
  ${EDK2_TOOLS}/GenFfs -t $1 -g $(uuidgen) -i $2 -o $3
}

# Create fv/ffs without SEC
cat ${BUILD_DIR}/fv_template.inf ${BUILD_DIR}/drivers.inf > ${BUILD_DIR}/fv_without_sec.inf
gen_fv ${BUILD_DIR}/fv_without_sec.inf ${BUILD_DIR}/fv_without_sec.fd
gen_sec EFI_SECTION_FIRMWARE_VOLUME_IMAGE ${BUILD_DIR}/fv_without_sec.fd ${BUILD_DIR}/fv_without_sec.sec
gen_ffs_from_sec EFI_FV_FILETYPE_FIRMWARE_VOLUME_IMAGE ${BUILD_DIR}/fv_without_sec.sec ${BUILD_DIR}/fv_without_sec.ffs

# Create fv/ffs with SEC
cat ${BUILD_DIR}/fv_template.inf ${BUILD_DIR}/drivers.inf > ${BUILD_DIR}/fv_with_sec.inf
echo "EFI_FILE_NAME = samples/ffs/sec.ffs" >> ${BUILD_DIR}/fv_with_sec.inf
gen_fv ${BUILD_DIR}/fv_with_sec.inf ${BUILD_DIR}/fv_with_sec.fd
gen_sec EFI_SECTION_FIRMWARE_VOLUME_IMAGE ${BUILD_DIR}/fv_with_sec.fd ${BUILD_DIR}/fv_with_sec.sec
gen_ffs_from_sec EFI_FV_FILETYPE_FIRMWARE_VOLUME_IMAGE ${BUILD_DIR}/fv_with_sec.sec ${BUILD_DIR}/fv_with_sec.ffs

# Create dummy SEC ffs without PE
cp samples/ffs/dummy.ffs ${BUILD_DIR}/
gen_sec EFI_SECTION_PE32 ${BUILD_DIR}/dummy.ffs ${BUILD_DIR}/dummy.sec
gen_ffs_from_sec EFI_FV_FILETYPE_SECURITY_CORE ${BUILD_DIR}/dummy.sec ${BUILD_DIR}/dummy.ffs

# Create compound fv
cp ${BUILD_DIR}/fv_template.inf ${BUILD_DIR}/fv_with_nested_sec.inf
echo "EFI_FILE_NAME = ${BUILD_DIR}/fv_without_sec.ffs" >> ${BUILD_DIR}/fv_with_nested_sec.inf
echo "EFI_FILE_NAME = ${BUILD_DIR}/dummy.ffs" >> ${BUILD_DIR}/fv_with_nested_sec.inf
echo "EFI_FILE_NAME = ${BUILD_DIR}/fv_with_sec.ffs" >> ${BUILD_DIR}/fv_with_nested_sec.inf
gen_fv ${BUILD_DIR}/fv_with_nested_sec.inf ${BUILD_DIR}/fv_with_nested_sec.fd

mkdir -p ${DEST_DIR}
cp ${BUILD_DIR}/*.fd ${DEST_DIR}/
