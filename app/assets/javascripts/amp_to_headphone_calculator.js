document.addEventListener("alpine:init", () => {
	Alpine.store("settings", {
		impedance: [null],
		get filteredImpedances() {
			return this.impedance.filter((imp) => imp !== null && imp > 0);
		},
		ampOutputImpedance: 0.1,
		r3: null,
		resistances: [
			1, 1.5, 1.8, 2.2, 2.7, 3.3, 3.9, 4.7, 5.6, 6.8, 8.2, 10, 12, 15, 18, 22,
			27, 33, 39, 47, 68, 82, 100,
		].map((r) => ({ value: r, selected: true })),
		get selectedResistances() {
			return this.resistances.filter((r) => r.selected);
		},
		minSpeakerLoad: 8,
		maxSpeakerLoad: 10,
		minAttenuation: 12,
		maxAttenuation: 16,
		minDampingFactor: 8,
		maxDampingFactor: 50,
		circuit: "l-pad",
		include: "all",
		get calculationComplete() {
			const valid = [];

			if (this.circuit === "three") {
				valid.push(
					this.selectedResistances
						.map((v) => v.value)
						.includes(parseFloat(this.r3)),
				);
			}

			valid.push(
				this.filteredImpedances.length > 0 &&
					this.filteredImpedances.every((val) => !Number.isNaN(val) && val > 0),
			);

			valid.push(
				!Number.isNaN(this.ampOutputImpedance) && this.ampOutputImpedance > 0,
			);

			valid.push(
				this.selectedResistances.length > 0 &&
					this.selectedResistances.every(
						({ value }) => !Number.isNaN(value) && value > 0,
					),
			);

			[
				this.minSpeakerLoad,
				this.maxSpeakerLoad,
				this.minAttenuation,
				this.maxAttenuation,
				this.minDampingFactor,
				this.maxDampingFactor,
			].forEach((val) => valid.push(!Number.isNaN(val) && val > 0));

			valid.push(["l-pad", "reversed-l-pad", "three"].includes(this.circuit));

			return valid.every((val) => val === true);
		},
		cellCache: new Map(),
		calculationsCache: new Map(),
		getSpeakerLoad(r1, r2) {
			const impedances = this.filteredImpedances;
			const circuit = this.circuit;
			const r3 = this.r3;

			if (circuit === "l-pad") {
				return impedances.map((imp) => {
					const key = `speaker-load-l-pad-${imp}-${r1}-${r2}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const result = r1 + 1 / (1 / r2 + 1 / imp);
					this.calculationsCache.set(key, result);
					return result;
				});
			}

			if (circuit === "reversed-l-pad") {
				return impedances.map((imp) => {
					const key = `speaker-load-reversed-l-pad-${imp}-${r1}-${r2}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const result = 1 / (1 / r1 + 1 / (r2 + imp));
					this.calculationsCache.set(key, result);
					return result;
				});
			}

			if (circuit === "three") {
				return impedances.map((imp) => {
					const key = `speaker-load-three-${imp}-${r1}-${r2}-${r3}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const result = 1 / (1 / (1 / (1 / imp + 1 / r3) + r2) + 1 / r1);
					this.calculationsCache.set(key, result);
					return result;
				});
			}
		},
		getAttenuation(r1, r2) {
			const impedances = this.filteredImpedances;
			const circuit = this.circuit;
			const r3 = this.r3;

			if (circuit === "l-pad") {
				return impedances.map((imp) => {
					const key = `attenuation-l-pad-${imp}-${r1}-${r2}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const reciprocalSum = this.safeDiv(r2) + this.safeDiv(imp);

					if (reciprocalSum === 0) {
						return 0;
					}

					const numerator = 1 / reciprocalSum;
					const denominator = r1 + 1 / reciprocalSum;
					const ratio = numerator / denominator;

					const result = Math.log10(ratio) * -20;
					this.calculationsCache.set(key, result);
					return result;
				});
			}

			if (circuit === "reversed-l-pad") {
				return impedances.map((imp) => {
					const key = `attenuation-reversed-l-pad-${imp}-${r2}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const denominator = r2 + imp;

					if (denominator === 0) {
						return 0;
					}

					const ratio = imp / denominator;

					const result = Math.log10(ratio) * -20;
					this.calculationsCache.set(key, result);
					return result;
				});
			}

			if (circuit === "three") {
				return impedances.map((imp) => {
					const key = `attenuation-three-${imp}-${r2}-${r3}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const reciprocalSum = this.safeDiv(r3) + this.safeDiv(imp);

					if (reciprocalSum === 0) {
						return 0;
					}

					const numerator = 1 / reciprocalSum;
					const denominator = r2 + 1 / reciprocalSum;
					const ratio = numerator / denominator;

					const result = Math.log10(ratio) * -20;
					this.calculationsCache.set(key, result);
					return result;
				});
			}
		},
		getDampingFactor(r1, r2) {
			const impedances = this.filteredImpedances;
			const circuit = this.circuit;
			const ampOutputImpedance = this.ampOutputImpedance;
			const r3 = this.r3;

			if (circuit === "l-pad") {
				return impedances.map((imp) => {
					const key = `damping-factor-l-pad-${imp}-${r1}-${r2}-${ampOutputImpedance}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const sumampOutputImpedance2 = ampOutputImpedance + r1;
					const reciprocalSum =
						this.safeDiv(sumampOutputImpedance2) + this.safeDiv(r2);

					if (reciprocalSum === 0) {
						return 0;
					}

					const result = imp / (1 / reciprocalSum);
					this.calculationsCache.set(key, result);
					return result;
				});
			}

			if (circuit === "reversed-l-pad") {
				return impedances.map((imp) => {
					const key = `damping-factor-reversed-l-pad-${imp}-${r1}-${r2}-${ampOutputImpedance}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const result = imp / (1 / (1 / ampOutputImpedance + 1 / r1) + r2);
					this.calculationsCache.set(key, result);
					return result;
				});
			}

			if (circuit === "three") {
				return impedances.map((imp) => {
					const key = `damping-factor-three-${imp}-${r1}-${r2}-${r3}-${ampOutputImpedance}`;
					if (this.calculationsCache.has(key)) {
						return this.calculationsCache.get(key);
					}

					const innerMost = this.safeDiv(ampOutputImpedance) + this.safeDiv(r1);
					const wrapped1 =
						ampOutputImpedance === 0 && r1 === 0 ? 0 : 1 / innerMost;
					const wrapped2 =
						ampOutputImpedance === 0 && r1 === 0 && r2 === 0
							? 0
							: 1 / (wrapped1 + r2);
					const denominatorPart = wrapped2 + this.safeDiv(r3);
					const finalDenominator =
						ampOutputImpedance === 0 && r1 === 0 && r2 === 0
							? 0
							: 1 / denominatorPart;

					const result = imp / finalDenominator;
					this.calculationsCache.set(key, result);
					return result;
				});
			}
		},
		getInRange(speakerLoad, attenuation, dampingFactor) {
			const impedances = this.filteredImpedances;
			const include = this.include;

			return impedances.map((imp, i) => {
				const inRange = {
					speakerLoad:
						speakerLoad[i] >= this.minSpeakerLoad &&
						speakerLoad[i] <= this.maxSpeakerLoad,
					attenuation:
						attenuation[i] >= this.minAttenuation &&
						attenuation[i] <= this.maxAttenuation,
					dampingFactor:
						dampingFactor[i] >= this.minDampingFactor &&
						dampingFactor[i] <= this.maxDampingFactor,
				};

				if (include === "all") {
					let sum = 0;
					[
						inRange.speakerLoad,
						inRange.attenuation,
						inRange.dampingFactor,
					].forEach((inRange) => (sum += inRange ? 1 : 0));
					return sum;
				}

				if (include === "speakerLoad") {
					return inRange.speakerLoad ? 3 : 0;
				}

				if (include === "attenuation") {
					return inRange.attenuation ? 3 : 0;
				}

				if (include === "dampingFactor") {
					return inRange.dampingFactor ? 3 : 0;
				}
			});
		},
		getBackground(inRange) {
			if (!this.calculationComplete) return null;

			let sum = 0;
			inRange.forEach((val) => (sum += val));
			const maxValue = inRange.length * 3;
			const percentage = sum / maxValue;

			return 80 * percentage;
		},
		safeDiv(val) {
			return val === 0 ? 0 : 1 / val;
		},
		getResult(r1, r2) {
			const cacheKey = this.getCacheKey(r1, r2);

			if (this.cellCache.has(cacheKey)) {
				return this.cellCache.get(cacheKey);
			}

			const result = this.calculateCell(r1, r2);
			this.cellCache.set(cacheKey, result);
			return result;
		},
		getCacheKey(r1, r2) {
			return `${this.circuit}-${this.include}-${r1}-${r2}-${this.r3}-${this.filteredImpedances.join(",")}-${this.ampOutputImpedance}-${this.minSpeakerLoad}-${this.maxSpeakerLoad}-${this.minAttenuation}-${this.maxAttenuation}-${this.minDampingFactor}-${this.maxDampingFactor}`;
		},
		calculateCell(r1, r2) {
			if (!this.calculationComplete) {
				return {
					speakerLoad: [],
					attenuation: [],
					dampingFactor: [],
					match: "none",
					background: null,
					inRange: 0,
				};
			}

			const speakerLoad = this.getSpeakerLoad(r1, r2);
			const attenuation = this.getAttenuation(r1, r2);
			const dampingFactor = this.getDampingFactor(r1, r2);
			const inRange = this.getInRange(speakerLoad, attenuation, dampingFactor);
			const background = this.getBackground(inRange);
			const match =
				inRange.length === 0
					? "none"
					: inRange.every((val) => val === 3)
						? "true"
						: "false";

			return {
				speakerLoad,
				attenuation,
				dampingFactor,
				inRange,
				background,
				match,
			};
		},
	});
});
