namespace teleport {

    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Canon;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Math;
    open Microsoft.Quantum.Diagnostics;
    
    @EntryPoint()
    operation Run(numTrials : Int) : Unit {
        let penalty = 20.0;
        let segmentCosts = [4.70, 9.09, 9.03, 5.70, 8.02, 1.71];
        let timeX = [0.619193, 0.742566, 0.060035, -1.568955, 0.045490];
        let timeZ = [3.182203, -1.139045, 0.221082, 0.537753, -0.417222];
        let limit = 1E-6;
        let numSegments = 6;

        mutable bestCost = 100.0 * penalty;
        mutable bestItinerary = [false, false, false, false, false];
        mutable successNumber = 0;

        let weights = HamiltonianWeights(segmentCosts, penalty, numSegments);
        let couplings = HamiltonianCouplings(penalty, numSegments);

        for trial in 0..numTrials {
            let result = PerformQAOA(
                numSegments, 
                weights, 
                couplings, 
                timeX, 
                timeZ
            );
            let cost = CalculatedCost(segmentCosts, result);
            let sat = IsSatisfactory(numSegments, result);
            Message($"result = {result}, cost = {cost}, satisfactory = {sat}");
            if (sat) {
                if (cost < bestCost - limit) {
                    // New best cost found - update
                    set bestCost = cost;
                    set bestItinerary = result;
                    set successNumber = 1;
                } elif (AbsD(cost - bestCost) < limit) {
                    set successNumber += 1;
                }
            }
        }
        let runPercentage = IntAsDouble(successNumber) * 100.0 / IntAsDouble(numTrials);
    }

    function HamiltonianWeights(
        segmentCosts : Double[], 
        penalty : Double, 
        numSegments : Int
    ) : Double[] {
        mutable weights = new Double[numSegments];
        for i in 0..numSegments - 1 {
            set weights w/= i <- 4.0 * penalty - 0.5 * segmentCosts[i];
        }
        return weights;
    }
    function HamiltonianCouplings(penalty : Double, numSegments : Int) : Double[] {
        return ConstantArray(numSegments * numSegments, 2.0 * penalty)
            w/ 2 <- penalty
            w/ 9 <- penalty
            w/ 29 <- penalty;
    }
    function CalculatedCost(segmentCosts : Double[], usedSegments : Bool[]) : Double {
        mutable finalCost = 0.0;
        for (cost, segment) in Zipped(segmentCosts, usedSegments) {
            set finalCost += segment ? cost | 0.0;
        }
        return finalCost;
    }
    function IsSatisfactory(numSegments: Int, usedSegments : Bool[]) : Bool {
        mutable hammingWeight = 0;
        for segment in usedSegments {
            set hammingWeight += segment ? 1 | 0;
        }
        if (hammingWeight != 4 
            or usedSegments[0] != usedSegments[2] 
            or usedSegments[1] != usedSegments[3] 
            or usedSegments[4] != usedSegments[5]) {
            return false;
        }
        return true;
    }

    operation PerformQAOA(
            numSegments : Int, 
            weights : Double[], 
            couplings : Double[], 
            timeX : Double[], 
            timeZ : Double[]
    ) : Bool[] {
        mutable result = new Bool[numSegments];
        use x = Qubit[numSegments];
        ApplyToEach(H, x);
        for (tz, tx) in Zipped(timeZ, timeX) {
            ApplyInstanceHamiltonian(numSegments, tz, weights, couplings, x); 
            ApplyDriverHamiltonian(tx, x); 
        }
        return ResultArrayAsBoolArray(MultiM(x)); 
    }

    operation ApplyDriverHamiltonian(time: Double, target: Qubit[]) : Unit is Adj + Ctl {
        ApplyToEachCA(Rx(-2.0 * time, _), target);
    }

    operation ApplyInstanceHamiltonian(
        numSegments : Int,
        time : Double, 
        weights : Double[], 
        coupling : Double[],
        target : Qubit[]
    ) : Unit {
        use auxiliary = Qubit();
        for (h, qubit) in Zipped(weights, target) {
            Rz(2.0 * time * h, qubit);
        }
        for i in 0..5 {
            for j in i + 1..5 {
                within {
                    CNOT(target[i], auxiliary);
                    CNOT(target[j], auxiliary);
                } apply {
                    Rz(2.0 * time * coupling[numSegments * i + j], auxiliary);
                }
            }
        }
    }
}
