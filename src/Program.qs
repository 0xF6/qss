namespace teleport {

    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Diagnostics;
    
    @EntryPoint()
    operation Run() : Unit {
        use q = Qubit();
        mutable iter = 1;
        mutable maxIters = 20;
        repeat {
            H(q);

            let bit = M(q);
            Reset(q);
            Message($"{bit}");
            set iter += 1;
        }
        until (iter > maxIters);
    }
}
