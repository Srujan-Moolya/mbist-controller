# Programmable MBIST Controller for SRAM

## 📌 Project Overview
This project implements a Memory Built-In Self-Test (MBIST) controller in Verilog. It is designed to verify the integrity of synchronous SRAM by running industry-standard test algorithms. The project includes parameterized memory models with dynamic fault-injection to prove the controller's diagnostic accuracy.

## 🚀 Features
* **Programmable FSM Controller:** Executes **March C-** (6-element) and **March SS** (3-element) algorithms.
* **Fault Injection Modeling:** Custom memory wrappers allow the injection of:
  * **Stuck-At Faults**
  * **Coupling Faults**
  * **Transition Faults**
* **Parallel Verification:** The testbench instantiates 5 concurrent DUTs (Device Under Test) to simultaneously verify the controller against both a golden memory and faulty memories.

## 🛠️ File Structure
* `src/mbist_controller.v`: The main programmable FSM tester.
* `src/memory_mut.v`: The golden Memory Under Test (MUT).
* `src/memory_faulty.v`: Memory model with parameter-driven fault injection.
* `src/mbist_top.v`: Top-level wiring between the controller and memory.
* `tb/tb_mbist.v`: The automated testbench evaluating 5 scenarios.

## 💻 How to Run (EDA Playground)
1. Go to [EDA Playground](https://edaplayground.com/).
2. Select **Icarus Verilog 0.10+ (2012)** as the simulator.
3. Paste the contents of the `src/` files into the **Design** panel.
4. Paste the contents of `tb_mbist.v` into the **Testbench** panel.
5. Click **Run** to view the fault-detection summary in the console.

## 📊 Expected Output
The testbench correctly identifies that the golden memories pass, while pinpointing the exact failure locations in the faulty models:

```text
---------------------- RESULTS ---------------------
DUT0 golden memory   / March C- : PASS (expected PASS)
DUT1 stuck-at fault  / March C- : FAIL (expected FAIL) -> element 1, addr 10, exp=255 got=247
DUT2 coupling fault  / March C- : FAIL (expected FAIL) -> element 2, addr 15, exp=0 got=4
DUT3 transition flt  / March C- : FAIL (expected FAIL) -> element 1, addr 20, exp=255 got=223
DUT4 golden memory   / March SS : PASS (expected PASS)
------------------------------------------------------
SUMMARY: All fault classes correctly DETECTED. Controller verified.
------------------------------------------------------
