#!/bin/bash

# Bash script to process all objects from 0 to 21 using kapture_mast3r_mapping_all.py
# This script runs the Python script for each object directory

# Base path where all object directories are located
BASE_PATH="/home/stefan/Downloads/dataset_test_real_labor"

# Path to the Python script
PYTHON_SCRIPT="./demo_colmap.py"

# Check if the Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "Error: Python script not found at $PYTHON_SCRIPT"
    exit 1
fi

# Check if the base path exists
if [ ! -d "$BASE_PATH" ]; then
    echo "Error: Base path not found at $BASE_PATH"
    exit 1
fi

echo "Starting kapture_mast3r_mapping processing for objects 0 to 21..."
echo "Base path: $BASE_PATH"
echo "Python script: $PYTHON_SCRIPT"
echo "========================================"

# Counter for successful and failed processing
success_count=0
failed_count=0
failed_objects=()


# Loop through objects 1 to 21
for i in {1..21}; do
    obj_num=$(printf "%06d" $i)
    obj_path="$BASE_PATH/obj_$obj_num"
    echo ""
    echo "Processing object $i (obj_$obj_num)..."
    echo "Object path: $obj_path"

    if [ ! -d "$obj_path" ]; then
        echo "Warning: Object directory not found: $obj_path"
        echo "Skipping obj_$obj_num"
        ((failed_count++))
        failed_objects+=("obj_$obj_num (directory not found)")
        continue
    fi

    # Process both segmented and surface under train_pbr/vggt
    for mode in segmented surface; do
        mode_dir="$obj_path/train_pbr/vggt/$mode"
        images_dir="$mode_dir/images"
        if [ ! -d "$images_dir" ]; then
            echo "Warning: $images_dir does not exist, skipping $mode for obj_$obj_num"
            continue
        fi

        echo "Running: python3 demo_colmap.py --scene_dir $mode_dir --use_ba --shared_camera --fine_tracking --query_frame_num 20"
        if python3 "$PYTHON_SCRIPT" --use_ba --scene_dir "$mode_dir" --shared_camera --fine_tracking --query_frame_num 20 --max_query_pts 4096; then
            echo "✓ Successfully processed $mode for obj_$obj_num"
        else
            echo "✗ Failed to process $mode for obj_$obj_num"
            ((failed_count++))
            failed_objects+=("obj_$obj_num ($mode failed)")
            continue
        fi

        # Export bundler
        sparse_dir="$mode_dir/sparse/0"
        output_dir="$mode_dir/images/scene"
        if [ -d "$sparse_dir" ]; then
            echo "Exporting bundler for $mode: colmap model_converter --input_path $sparse_dir --output_path $output_dir --output_type BUNDLER"
            if colmap model_converter --input_path "$sparse_dir" --output_path "$output_dir" --output_type BUNDLER; then
                echo "✓ Bundler export successful for $mode of obj_$obj_num"
            else
                echo "✗ Bundler export failed for $mode of obj_$obj_num"
                ((failed_count++))
                failed_objects+=("obj_$obj_num ($mode bundler export failed)")
            fi
        else
            echo "Warning: $sparse_dir does not exist, skipping bundler export for $mode of obj_$obj_num"
        fi
    done

    echo "----------------------------------------"
done

echo ""
echo "========================================"
echo "COLMAP VGGT PROCESSING COMPLETE"
echo "========================================"
echo "Total objects processed: $((success_count + failed_count))"
echo "Successful: $success_count"
echo "Failed: $failed_count"

if [ $failed_count -gt 0 ]; then
    echo ""
    echo "Failed objects:"
    for failed_obj in "${failed_objects[@]}"; do
        echo "  - $failed_obj"
    done
fi

echo ""
if [ $failed_count -eq 0 ]; then
    echo "All objects processed successfully!"
    echo "3D reconstructions have been generated in:"
    echo "  - {object}/train_pbr/vggt/surface/sparse/"
    echo "  - {object}/train_pbr/vggt/segmented/sparse/"
    exit 0
else
    echo "Some objects failed to process. Check the logs above for details."
    exit 1
fi
