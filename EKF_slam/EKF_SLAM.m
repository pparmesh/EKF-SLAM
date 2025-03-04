%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  16833 Robot Localization and Mapping  % 
%  Assignment #2                         %
%  EKF-SLAM                              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear;
close all;
clc;

%==== TEST: Setup uncertainity parameters (try different values!) ===
sig_x = 0.25;
sig_y = 0.1;
sig_alpha = 0.1;
sig_beta = 0.01;
sig_r = 0.08;

%==== Generate sigma^2 from sigma ===
sig_x2 = sig_x^2;
sig_y2 = sig_y^2;
sig_alpha2 = sig_alpha^2;
sig_beta2 = sig_beta^2;
sig_r2 = sig_r^2;

%==== Open data file ====
fid = fopen('../data/data.txt');

%==== Read first measurement data ====
tline = fgets(fid);
arr = str2num(tline);
measure = arr';
t = 1;
 
%==== Setup control and measurement covariances ===
control_cov = diag([sig_x2, sig_y2, sig_alpha2]);
measure_cov = diag([sig_beta2, sig_r2]);

%==== Setup initial pose vector and pose uncertainty ====
pose = [0 ; 0 ; 0];
pose_cov = diag([0.02^2, 0.02^2, 0.1^2]);

%==== TODO: Setup initial landmark vector landmark[] and covariance matrix landmark_cov[] ====
%==== (Hint: use initial pose with uncertainty and first measurement) ====
k = 6; % Number of landarks
measure = reshape(measure, [2,6]);
measure = measure';
landmark = zeros(6,2);
landmark_cov = zeros(12,12);
idx = 1;
measure_cov_fl = diag([sig_r2, sig_beta2]);

% Iterate over landmark measurements to intialize lx, ly
for i = 1:6
    landmark(i,1) = pose(1) + measure(i,2)*cos(pose(3) + measure(i,1));
    landmark(i,2) = pose(2) + measure(i,2)*sin(pose(3) + measure(i,1));
    Hp = [1 0 -measure(i,2)*sin(pose(3)+measure(i,1)); 0 1 measure(i,2)*cos(pose(3) + measure(i,1))];
    Hm = [-measure(i,2)*sin(pose(3)+measure(i,1)) cos(pose(3) + measure(i,1)); measure(i,2)*cos(pose(3)+measure(i,1)) sin(pose(3)+measure(i,1))];
    curr_sigma = Hp*pose_cov*Hp' + Hm*measure_cov*Hm';
    landmark_cov(idx:idx+1,idx:idx+1) = curr_sigma;
    idx = idx + 2;
end
landmark = landmark';
landmark = reshape(landmark, [12,1]);

%==== Setup state vector x with pose and landmark vector ====
x = [pose ; landmark];

%==== Setup covariance matrix P with pose and landmark covariances ====
P = [pose_cov zeros(3, 2*k) ; zeros(2*k, 3) landmark_cov];

%==== Plot initial state and conariance ====
last_x = x;
drawTrajAndMap(x, last_x, P, 0);

Fx = zeros(3,3+2*k);
Fx(1,1) = 1;
Fx(2,2) = 1;
Fx(3,3) = 1;
%==== Read control data ====
tline = fgets(fid);
while ischar(tline)
    arr = str2num(tline);
    d = arr(1);
    alpha = arr(2);
    
    %==== TODO: Predict Step ====
    %==== (Notice: predict state x_pre[] and covariance P_pre[] using input control data and control_cov[]) ====
    
    % Write your code here...
    ut = [d*cos(x(3)); d*sin(x(3)); alpha];
    % Predict the state 
    x_pre = x + Fx'*ut; 
    G_temp = [0 0 -d*sin(x(3)); 0 0 d*cos(x(3)); 0 0 0];
    G = eye(3+2*k) + Fx'*G_temp*Fx; % Jacobian
    % Predict covariance
    Rtrans = [cos(x(3)) -sin(x(3)) 0; sin(x(3)) cos(x(3)) 0; 0 0 1];
    P_pre = G*P*G' + Fx'*Rtrans*control_cov*Rtrans'*Fx;
    
    
    %==== Draw predicted state x_pre[] and covariance P_pre[] ====
    drawTrajPre(x_pre, P_pre);
    
    %==== Read measurement data ====
    tline = fgets(fid);
    arr = str2num(tline);
    measure = arr';
    
    %==== TODO: Update Step ====
    %==== (Notice: update state x[] and covariance P[] using input measurement data and measure_cov[]) ====
    
    % Write your code here...
    % Iterate over landmarks. Correspondences are in order
    pred_landmarks = x(4:end); % get predicted landmarks
    pred_landmarks = reshape(pred_landmarks,[2,k]);
    pred_landmarks = pred_landmarks';
    
    measured_landmarks = reshape(arr, [2,k]);
    measured_landmarks = measured_landmarks';
    measured_landmarks = fliplr(measured_landmarks);
    
    Fxj = zeros(5, 2*k+3);
    Fxj(1:3,1:3) = eye(3);
    Fx_meas = [0 0; 0 0; 0 0; 1 0; 0 1];
    idx1 = 4;
    for i=1:6
        del = [pred_landmarks(i,1) - x_pre(1); pred_landmarks(i,2) - x_pre(2)];
        q = del'*del;
        pred_meas = [sqrt(q); wrapToPi(atan2(del(2),del(1)) - x_pre(3))];
        Fxj(1:end,idx1:idx1+1) = Fx_meas;
        idx1 = idx1 + 2;
        Hi = (1/q)*[-sqrt(q)*del(1), -sqrt(q)*del(2), 0, sqrt(q)*del(1), sqrt(q)*del(2); del(2), -del(1), -q, -del(2), del(1)]*Fxj;
        
        % Calculate Kalman Gain
        Ki = P_pre*Hi'*inv(Hi*P_pre*Hi' + measure_cov_fl);
        x_pre = x_pre + Ki*([measured_landmarks(i,1);measured_landmarks(i,2)] - pred_meas);
        P_pre = (eye(15) -Ki*Hi)*P_pre;
    end
    x = x_pre;
    P = P_pre;
       
    
    %==== Plot ====   
    drawTrajAndMap(x, last_x, P, t);
    last_x = x;
    
    %==== Iteration & read next control data ===
    t = t + 1;
    tline = fgets(fid);
end

%==== EVAL: Plot ground truth landmarks ====

% Write your code here...
gt_vals = [3 6 3 12 7 8 7 14 11 6 11 12];
gt_x = zeros(1,6);
gt_y = zeros(1,6);
est_x = zeros(1,6);
est_y = zeros(1,6);
est_l = x(4:end);

for i = 1:6
    gt_x(i) = gt_vals(2*i-1);
    gt_y(i) = gt_vals(2*i);
    est_x(i) = est_l(2*i-1);
    est_y(i) = est_l(2*i);
end
hold on
scatter(gt_x,gt_y,25,'filled');
x_diff = (est_x - gt_x).^2;
y_diff = (est_y - gt_y).^2;
euclidean_dist = (x_diff+y_diff).^0.5;
    
    

%==== Close data file ====
fclose(fid);
