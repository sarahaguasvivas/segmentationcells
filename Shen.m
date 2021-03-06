%{

Sarah Aguasvivas Manzano

MATLAB R2017b

This program has the purpose to ultimately segment an image in order
to find the relative intensity of the signal in Channel 1 based on the
cell walls form Channel 2.

----------Requirements:-----------
-Latest version of MATLAB (R2017b)
-Computer with GPU capabilities (also GPU driver up to date (update CUDA))

For reference it was developed in 
a Mac OS Sierra with CUDA and these specs from gpuDevice
 
                      Name: 'NVIDIA GeForce GT 650M'
                     Index: 1
         ComputeCapability: '3.0'
            SupportsDouble: 1
             DriverVersion: 8
            ToolkitVersion: 8
        MaxThreadsPerBlock: 1024
          MaxShmemPerBlock: 49152
        MaxThreadBlockSize: [1024 1024 64]
               MaxGridSize: [1�3 double]
                 SIMDWidth: 32
               TotalMemory: 1.0734e+09
           AvailableMemory: 82386944
       MultiprocessorCount: 2
              ClockRateKHz: 900000
               ComputeMode: 'Default'
      GPUOverlapsTransfers: 1
    KernelExecutionTimeout: 1
          CanMapHostMemory: 1
           DeviceSupported: 1
            DeviceSelected: 1

%}

clear;
clc;

%%% Importing iamges to MATLAB environment:
addpath('~/Desktop/');
ch1= imread('Control-FL.tif');
ch2= imread('Control-BF.tif');
% Making images smaller:

net= denoisingNetwork('dncnn'); % using MATLAB's pretrained network for denoising


%% PASSING CH2 THROUGH HPF:

ch1= double(ch1);
ch2= double(ch2);

%{ 
To make this high-pass filter effective, I am 
firts applying an FFT to the image in order to do
a Gaussian decomposition in the frequency domain
%}

FFT2= fft2(ch2);
FFTs= fftshift(FFT2);

% From https://www.mathworks.com/matlabcentral/fileexchange/46812-two-
% dimensional-gaussian-hi-pass-and-low-pass-image-filter

[M N]=size(FFTs); % image size
R=10; % filter size parameter 
X=0:N-1;
Y=0:M-1;
[X Y]=meshgrid(X,Y);
Cx=0.5*N;
Cy=0.5*M;
LPF=exp(-((X-Cx).^2+(Y-Cy).^2)./(2*R).^2); %Low pass filter
HPF1=1-LPF; % High pass filter

% Filtered image= ifft(filter_response*fft(original_image))

K=FFTs.*HPF1;
K1=ifftshift(K);
HPF=ifft2(K1);  % we want to keep HPF

clear ans Cx Cy FFT2 FFTs HPF1 K K1 LPF M N X Y R
%% BEFORE EDGE DETECTION, I WANT TO REDUCE NOISE
% I tried using 'imerode o watershed', but those won't reduce 
% the noise to the level that we want. I applied a Deep Neural Network to 
% sweep out the noise. You will have to install Matlab 9.0 and the new Neural Network
% Package for image visualization and recognition. PSU provides that, I
% believe. Also you might need to open an ACI account and run this on their
% cluster. I was getting memory issues, so I divided my picture into mini
% pictures and applied the denoising. Since the initial layer of net is an 
% image that is 50x50x1, I had to separate B2 into 50x50 squares due to 
% memory problems
HPF1= medfilt2(HPF);

[N, M] = size(HPF1);
tic
gpuDevice();

for i=1:255:N-255
    for j=1:255:M-255
        HPF1(i:i+254, j:j+254)= denoiseImage(HPF1(i:i+254, j:j+254), net);
    end
end

toc
%% EDGE DETECTION:
% Aqui se hizo magia pero se logr�. Esta parte agarra la foto en double 
% la convierte en binaria luego de aplicar un gaussian filter. El delivery
% de esta parte del c�digo es los bordes (dale zoom) y la imagen lista para
% calcular las intensidades usando BWperim

sigma = 10;
smoothImage = imgaussfilt(HPF1,sigma);
HPF2 = im2bw(smoothImage, 1);
BW= bwareaopen(~HPF2, 10000, conndef(2, 'maximal'));


%...detecting borders...
bwopen= bwareaopen(~BW, 100);
BWperim= bwperim(bwopen);
%%
ch2=uint8(ch2);
figure('Name', 'Steps toward Edge Detection')
subplot(2,2,1)
overlay1= imoverlay(ch2, BWperim, 'white');
imshow(overlay1)
title('ch2')
subplot(2, 2, 2)
imshow(HPF1)
title('HPF1')
subplot(2,2,3)
imshow(~BW)
title('BW')
subplot(2,2,4)
overlay= imoverlay(BW, BWperim, 'red');
imshow(overlay);
title('edge')

figure()
imshow(overlay1);

% BWperim es lo que se va a usar para calcular las intensidades del channel
% 1


