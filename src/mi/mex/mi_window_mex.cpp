#include "mex.h"
#include "matrix.h"

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <cstring>
#include <vector>

namespace {

template <typename T>
inline int32_t readBin(const T* data, mwSize row, mwSize col, mwSize nRows) {
    return static_cast<int32_t>(data[row + col * nRows]);
}

inline double sampleStd(const std::vector<double>& values) {
    const mwSize n = values.size();
    if (n <= 1) {
        return 0.0;
    }

    double sum = 0.0;
    for (double value : values) {
        sum += value;
    }
    const double mean = sum / static_cast<double>(n);

    double accum = 0.0;
    for (double value : values) {
        const double delta = value - mean;
        accum += delta * delta;
    }

    return std::sqrt(accum / static_cast<double>(n - 1));
}

inline double medianOfVector(std::vector<double>& values) {
    const mwSize n = values.size();
    if (n == 0) {
        return 0.0;
    }

    const mwSize mid = n / 2;
    std::nth_element(values.begin(), values.begin() + mid, values.end());
    const double upper = values[mid];

    if ((n % 2) == 1) {
        return upper;
    }

    std::nth_element(values.begin(), values.begin() + mid - 1, values.begin() + mid);
    const double lower = values[mid - 1];
    return 0.5 * (lower + upper);
}

template <typename T>
void computeMiVector(
    const T* binData,
    mwSize nFreqs,
    mwSize freqIndex,
    mwIndex windowStart,
    mwSize windowDur,
    const int32_T* dtFrames,
    mwSize nDelays,
    int32_t nBins,
    const double* phiLut,
    std::vector<int32_t>& baseBins,
    std::vector<int32_t>& shiftedBins,
    std::vector<int32_t>& hist,
    std::vector<double>& rowSums,
    std::vector<double>& colSums,
    double logWindowDur,
    double* output)
{
    const int32_t histSize = nBins * nBins;
    std::fill(hist.begin(), hist.end(), 0);

    for (mwSize w = 0; w < windowDur; ++w) {
        baseBins[w] = readBin(binData, freqIndex, windowStart + w, nFreqs);
    }

    for (mwSize d = 0; d < nDelays; ++d) {
        const mwIndex shiftedStart = static_cast<mwIndex>(static_cast<int32_t>(windowStart + 1) + dtFrames[d] - 1);
        const mwSize shiftedOffset = d * windowDur;
        const mwSize histOffset = d * histSize;

        for (mwSize w = 0; w < windowDur; ++w) {
            const int32_t shiftedValue = readBin(binData, freqIndex, shiftedStart + w, nFreqs);
            shiftedBins[shiftedOffset + w] = shiftedValue;
            const int32_t pairIdx = baseBins[w] * nBins + shiftedValue;
            hist[histOffset + pairIdx] += 1;
        }
    }

    for (mwSize d = 0; d < nDelays; ++d) {
        std::fill(rowSums.begin(), rowSums.end(), 0.0);
        std::fill(colSums.begin(), colSums.end(), 0.0);

        double jointPhi = 0.0;
        const mwSize histOffset = d * histSize;

        for (int32_t c = 0; c < nBins; ++c) {
            const mwSize colOffset = histOffset + static_cast<mwSize>(c) * nBins;
            for (int32_t r = 0; r < nBins; ++r) {
                const int32_t count = hist[colOffset + r];
                if (count > 0) {
                    const double countAsDouble = static_cast<double>(count);
                    jointPhi += phiLut[count];
                    rowSums[r] += countAsDouble;
                    colSums[c] += countAsDouble;
                }
            }
        }

        double rowPhi = 0.0;
        double colPhi = 0.0;

        for (int32_t r = 0; r < nBins; ++r) {
            rowPhi += phiLut[static_cast<mwIndex>(rowSums[r])];
        }
        for (int32_t c = 0; c < nBins; ++c) {
            colPhi += phiLut[static_cast<mwIndex>(colSums[c])];
        }

        output[d] = logWindowDur + (jointPhi - rowPhi - colPhi) / static_cast<double>(windowDur);
    }
}

template <typename T>
void computeForType(
    const T* binData,
    mwSize nFreqs,
    mwIndex windowStart,
    mwSize windowDur,
    const int32_T* dtFrames,
    mwSize nDelays,
    int32_t nBins,
    const double* phiLut,
    const int32_T* baseOrders,
    mwSize nPerms,
    const int32_T* shiftedLinearIdx,
    double* miOut,
    double* shiftMeanOut,
    double* shiftMedianOut,
    double* shiftStdOut)
{
    const int32_t histSize = nBins * nBins;
    const double logWindowDur = std::log(static_cast<double>(windowDur));

    std::vector<int32_t> baseBins(windowDur);
    std::vector<int32_t> shiftedBins(windowDur * nDelays);
    std::vector<int32_t> hist(static_cast<mwSize>(histSize) * nDelays);
    std::vector<double> rowSums(nBins);
    std::vector<double> colSums(nBins);
    std::vector<double> miBuffer(nDelays);
    std::vector<int32_t> basePerm(windowDur);
    std::vector<int32_t> shiftedPerm(windowDur * nDelays);
    std::vector<int32_t> permHist(static_cast<mwSize>(histSize) * nDelays);
    std::vector<double> permBuffer(nDelays);
    std::vector<double> permMi(nDelays * nPerms);
    std::vector<double> medianBuffer(nPerms);

    for (mwSize fi = 0; fi < nFreqs; ++fi) {
        computeMiVector(
            binData, nFreqs, fi, windowStart, windowDur, dtFrames, nDelays, nBins, phiLut,
            baseBins, shiftedBins, hist, rowSums, colSums, logWindowDur, miBuffer.data());

        for (mwSize d = 0; d < nDelays; ++d) {
            miOut[fi + d * nFreqs] = miBuffer[d];
        }

        if (nPerms == 0) {
            continue;
        }

        for (mwSize pi = 0; pi < nPerms; ++pi) {
            for (mwSize w = 0; w < windowDur; ++w) {
                basePerm[w] = baseBins[static_cast<mwIndex>(baseOrders[pi + w * nPerms] - 1)];
            }

            for (mwSize d = 0; d < nDelays; ++d) {
                const mwSize delayOffset = d * windowDur;
                for (mwSize w = 0; w < windowDur; ++w) {
                    const mwIndex linearIdx =
                        static_cast<mwIndex>(shiftedLinearIdx[w + d * windowDur + pi * windowDur * nDelays] - 1);
                    shiftedPerm[delayOffset + w] = shiftedBins[linearIdx];
                }
            }

            std::fill(permHist.begin(), permHist.end(), 0);
            for (mwSize d = 0; d < nDelays; ++d) {
                const mwSize delayOffset = d * windowDur;
                const mwSize histOffset = d * histSize;
                for (mwSize w = 0; w < windowDur; ++w) {
                    const int32_t pairIdx = basePerm[w] * nBins + shiftedPerm[delayOffset + w];
                    permHist[histOffset + pairIdx] += 1;
                }
            }

            for (mwSize d = 0; d < nDelays; ++d) {
                std::fill(rowSums.begin(), rowSums.end(), 0.0);
                std::fill(colSums.begin(), colSums.end(), 0.0);

                double jointPhi = 0.0;
                const mwSize histOffset = d * histSize;
                for (int32_t c = 0; c < nBins; ++c) {
                    const mwSize colOffset = histOffset + static_cast<mwSize>(c) * nBins;
                    for (int32_t r = 0; r < nBins; ++r) {
                        const int32_t count = permHist[colOffset + r];
                        if (count > 0) {
                            const double countAsDouble = static_cast<double>(count);
                            jointPhi += phiLut[count];
                            rowSums[r] += countAsDouble;
                            colSums[c] += countAsDouble;
                        }
                    }
                }

                double rowPhi = 0.0;
                double colPhi = 0.0;
                for (int32_t r = 0; r < nBins; ++r) {
                    rowPhi += phiLut[static_cast<mwIndex>(rowSums[r])];
                }
                for (int32_t c = 0; c < nBins; ++c) {
                    colPhi += phiLut[static_cast<mwIndex>(colSums[c])];
                }

                permBuffer[d] = logWindowDur + (jointPhi - rowPhi - colPhi) / static_cast<double>(windowDur);
                permMi[d + pi * nDelays] = permBuffer[d];
            }
        }

        for (mwSize d = 0; d < nDelays; ++d) {
            double sum = 0.0;
            for (mwSize pi = 0; pi < nPerms; ++pi) {
                const double value = permMi[d + pi * nDelays];
                medianBuffer[pi] = value;
                sum += value;
            }

            const double mean = sum / static_cast<double>(nPerms);
            shiftMeanOut[fi + d * nFreqs] = mean;
            shiftMedianOut[fi + d * nFreqs] = medianOfVector(medianBuffer);
            shiftStdOut[fi + d * nFreqs] = sampleStd(medianBuffer);
        }
    }
}

void dispatchCompute(
    const mxArray* binMatrix,
    mwIndex windowStart,
    mwSize windowDur,
    const int32_T* dtFrames,
    mwSize nDelays,
    int32_t nBins,
    const double* phiLut,
    const int32_T* baseOrders,
    mwSize nPerms,
    const int32_T* shiftedLinearIdx,
    double* miOut,
    double* shiftMeanOut,
    double* shiftMedianOut,
    double* shiftStdOut)
{
    const mwSize nFreqs = mxGetM(binMatrix);

    switch (mxGetClassID(binMatrix)) {
        case mxUINT8_CLASS:
            computeForType<uint8_T>(
                static_cast<const uint8_T*>(mxGetData(binMatrix)), nFreqs, windowStart, windowDur,
                dtFrames, nDelays, nBins, phiLut, baseOrders, nPerms, shiftedLinearIdx,
                miOut, shiftMeanOut, shiftMedianOut, shiftStdOut);
            break;
        case mxUINT16_CLASS:
            computeForType<uint16_T>(
                static_cast<const uint16_T*>(mxGetData(binMatrix)), nFreqs, windowStart, windowDur,
                dtFrames, nDelays, nBins, phiLut, baseOrders, nPerms, shiftedLinearIdx,
                miOut, shiftMeanOut, shiftMedianOut, shiftStdOut);
            break;
        case mxUINT32_CLASS:
            computeForType<uint32_T>(
                static_cast<const uint32_T*>(mxGetData(binMatrix)), nFreqs, windowStart, windowDur,
                dtFrames, nDelays, nBins, phiLut, baseOrders, nPerms, shiftedLinearIdx,
                miOut, shiftMeanOut, shiftMedianOut, shiftStdOut);
            break;
        default:
            mexErrMsgIdAndTxt("mi_window_mex:UnsupportedType", "bin_matrix должен быть uint8, uint16 или uint32.");
    }
}

} // namespace

void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[]) {
    if (nrhs != 8) {
        mexErrMsgIdAndTxt("mi_window_mex:InputCount", "Ожидается 8 входных аргументов.");
    }
    if (nlhs > 4) {
        mexErrMsgIdAndTxt("mi_window_mex:OutputCount", "Допустимо не более 4 выходных аргументов.");
    }

    const mxArray* binMatrix = prhs[0];
    const mxArray* windowStartArr = prhs[1];
    const mxArray* windowDurArr = prhs[2];
    const mxArray* dtFramesArr = prhs[3];
    const mxArray* nBinsArr = prhs[4];
    const mxArray* phiLutArr = prhs[5];
    const mxArray* baseOrdersArr = prhs[6];
    const mxArray* shiftedIdxArr = prhs[7];

    if (!mxIsInt32(windowStartArr) || !mxIsInt32(windowDurArr) || !mxIsInt32(dtFramesArr) ||
        !mxIsInt32(nBinsArr) || !mxIsInt32(baseOrdersArr) || !mxIsInt32(shiftedIdxArr)) {
        mexErrMsgIdAndTxt("mi_window_mex:Type", "Индексные аргументы должны быть int32.");
    }
    if (!mxIsDouble(phiLutArr) || mxIsComplex(phiLutArr)) {
        mexErrMsgIdAndTxt("mi_window_mex:PhiLutType", "phi_lut должен быть вещественным double.");
    }

    const mwSize nFreqs = mxGetM(binMatrix);
    const mwIndex windowStart = static_cast<mwIndex>(*static_cast<int32_T*>(mxGetData(windowStartArr)) - 1);
    const mwSize windowDur = static_cast<mwSize>(*static_cast<int32_T*>(mxGetData(windowDurArr)));
    const int32_T* dtFrames = static_cast<int32_T*>(mxGetData(dtFramesArr));
    const mwSize nDelays = mxGetNumberOfElements(dtFramesArr);
    const int32_t nBins = *static_cast<int32_T*>(mxGetData(nBinsArr));
    const double* phiLut = mxGetPr(phiLutArr);
    const mwSize nPerms = mxGetM(baseOrdersArr);

    plhs[0] = mxCreateDoubleMatrix(nFreqs, nDelays, mxREAL);
    double* miOut = mxGetPr(plhs[0]);

    double* shiftMeanOut = nullptr;
    double* shiftMedianOut = nullptr;
    double* shiftStdOut = nullptr;

    if (nlhs > 1) {
        plhs[1] = mxCreateDoubleMatrix(nFreqs, nDelays, mxREAL);
        shiftMeanOut = mxGetPr(plhs[1]);
    }
    if (nlhs > 2) {
        plhs[2] = mxCreateDoubleMatrix(nFreqs, nDelays, mxREAL);
        shiftMedianOut = mxGetPr(plhs[2]);
    }
    if (nlhs > 3) {
        plhs[3] = mxCreateDoubleMatrix(nFreqs, nDelays, mxREAL);
        shiftStdOut = mxGetPr(plhs[3]);
    }

    if (nPerms == 0) {
        return;
    }

    if (shiftMeanOut == nullptr || shiftMedianOut == nullptr || shiftStdOut == nullptr) {
        mexErrMsgIdAndTxt("mi_window_mex:OutputCount", "Для режима с permutations нужны 4 выхода.");
    }

    dispatchCompute(
        binMatrix,
        windowStart,
        windowDur,
        dtFrames,
        nDelays,
        nBins,
        phiLut,
        static_cast<int32_T*>(mxGetData(baseOrdersArr)),
        nPerms,
        static_cast<int32_T*>(mxGetData(shiftedIdxArr)),
        miOut,
        shiftMeanOut,
        shiftMedianOut,
        shiftStdOut);
}
