import pandas as pd
import matplotlib.pyplot as plt
import os

# Configuration
data_path = "../data"
img_path = "../../plots/"
files = {
    "bandwidth-1.csv": "Intra-node (1 Node, 2 Tasks)",
    "bandwidth-2.csv": "Inter-node (2 Nodes, 2 Tasks)"
}

# Ensure the output directory exists
os.makedirs(img_path, exist_ok=True)

def plot_bandwidth():
    # We iterate through each file to create separate plots
    for filename, display_name in files.items():
        file_full_path = os.path.join(data_path, filename)
        
        if not os.path.exists(file_full_path):
            print(f"Warning: {file_full_path} not found.")
            continue

        # Load data
        df = pd.read_csv(file_full_path)
        
        # Create a new figure for each file
        plt.figure(figsize=(10, 6))

        # Styles for this specific plot
        # Using index 1 for Blocking, 0 for Non-Blocking
        is_blocking_map = {
            1: {'label': 'Blocking', 'color': '#1f77b4' if '1' in filename else '#d62728', 'marker': 'o'},
            0: {'label': 'Non-Blocking', 'color': '#17becf' if '1' in filename else '#ff7f0e', 'marker': 's'}
        }

        for is_blocking, style in is_blocking_map.items():
            subset = df[df['Is_Blocking'] == is_blocking]
            if subset.empty:
                continue
                
            plt.plot(
                subset['KB_Size'], 
                subset['Bandwidth_MBs'], 
                label=style['label'],
                color=style['color'],
                marker=style['marker'],
                linewidth=2,
                markersize=8
            )

        # Formatting
        plt.xscale('log', base=2)
        plt.xlabel('Message Size (KB)', fontsize=12)
        plt.ylabel('Bandwidth (MB/s)', fontsize=12)
        plt.title(f'MPI Bandwidth: {display_name}', fontsize=14)
        
        ticks = [1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024]
        plt.xticks(ticks, ticks)
        
        plt.grid(True, which="both", ls="-", alpha=0.5)
        plt.legend()
        plt.tight_layout()

        # Generate filename based on the input csv name
        save_name_png = filename.replace('.csv', '.png')
        save_name_svg = filename.replace('.csv', '.svg')
        full_save_path_png = os.path.join(img_path, save_name_png)
        full_save_path_svg = os.path.join(img_path, save_name_svg)
        
        plt.savefig(full_save_path_png)
        plt.savefig(full_save_path_svg)
        print(f"🚀 Plot saved as '{full_save_path_png}' and '{full_save_path_svg}'")
        
        # Show each plot sequentially
        plt.show()

if __name__ == "__main__":
    plot_bandwidth()
