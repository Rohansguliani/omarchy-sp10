//! About: the machine and the system, read once when the page opens.

use super::kit::*;
use crate::theme::fixed;
use anti_webui::prelude::*;

const SCRIPT: &str = r#"
model=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
vendor=$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)
cpu=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
gpu=$(lspci 2>/dev/null | awk -F': ' '/VGA|3D|Display/{print $2}' | sed -E 's/ \(rev .*//; s/^Intel Corporation /Intel /' | paste -sd ', ')
mem=$(awk '/MemTotal/{printf "%.0f GB", $2/1048576}' /proc/meminfo)
disk=$(df -h --output=used,size / | awk 'NR==2{print $1 " used of " $2}')
omarchy=$(omarchy version 2>/dev/null | head -1)
kernel=$(uname -r)
printf 'Model\t%s %s\nProcessor\t%s\nGraphics\t%s\nMemory\t%s\nStorage\t%s\nOmarchy\t%s\nKernel\t%s\n' "$vendor" "$model" "$cpu" "$gpu" "$mem" "$disk" "$omarchy" "$kernel"
"#;

pub fn page() -> Div {
    let facts = signal(Vec::<(String, String)>::new());
    run_output(argv(&["sh", "-c", SCRIPT])).then(move |out| {
        facts.set(
            out.lines()
                .filter_map(|l| l.split_once('\t'))
                .map(|(k, v)| (k.to_owned(), v.trim().to_owned()))
                .collect(),
        );
    });
    sheet("About").child(group().child(dyn_view(move || {
        let mut g = div().flex().flex_col();
        for (k, v) in facts.get() {
            let v2 = v.clone();
            g = g.child(
                row().child(fixed(13.0, k).w(110.0_f32)).child(
                    value(move || v2.clone())
                        .flex_1()
                        .min_w(0.0)
                        .overflow_hidden(),
                ),
            );
            let _ = v;
        }
        g.into_view()
    })))
}
