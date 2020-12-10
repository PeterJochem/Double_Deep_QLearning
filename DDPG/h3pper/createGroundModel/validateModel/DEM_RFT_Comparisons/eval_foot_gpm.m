%% eval_foot_gpm.m
%
% Description:
%   Evaluate general planar foot motion by comparing DEM data (generated by
%   Chrono) to RFT-based simulation.
%
% Inputs:
%   path_to_csvs: a string providing the path (relative or absolute) to 3
%       CSVs (output_
%
% Outputs:
%   none

function eval_foot_gpm(path_to_csvs)
%% Initialize workspace
% clear all;
close all;
% clc;

% addpath('../')
% init_env();

params = init_params;
params.gnd = params.DEM; % switch terrain to DEM

params.geom.foot_radius = 0.025; % distance from foot CoM [m]
params.geom.foot_height = 0.0025; % [m]
params.foot_mass = 0.25;   % [kg]
params.foot_moment_of_inertia = params.foot_mass*...
    (params.geom.foot_radius^2)/3;    % [kg m^2], foot = slender rod


% add light damping to CoM:
% params.sim.type = 'opt';
% params.gnd.damping.x = 0;
% params.gnd.damping.y = 0;
% params.gnd.damping.theta = 0.0;

%% Read data from CSV files generated by Chrono
% skip row 1, contains a negative time index:
start_row = 2502; % no foot motion until 5 seconds into the simulation

impact_speed_MKS = csvread(...
    fullfile(path_to_csvs,'/output_plate_velocities.csv'),...
    0,0,[0,0,0,0]);
impact_angle_rad = pi/6;

pf = csvread(fullfile(path_to_csvs,'/output_plate_positions.csv'),start_row);
vf = csvread(fullfile(path_to_csvs,'/output_plate_velocities.csv'),start_row);
ff = csvread(fullfile(path_to_csvs,'/output_plate_forces.csv'),start_row);

%% Parse data from CSVs
% 1a) parse time:
t1 = pf(:,1);
t2 = vf(:,1);
t3 = ff(:,1);

if ((min(t1==t2)==1) && min(t2==t3)==1)
    % all 3 time series are identical, we can pick any one.
    t = t1;
else
    % for now, just throw an error:
    error('Timeseries from position, velocity, and force CSVs do not match.');
    % could add error handling later, idk
end

% 1b) subtract off idle time so t begins at 0:
t = t - t(1);

% 2a) parse x-, y-, and z-positions:
px = pf(:,2);
py = pf(:,3);
pz = pf(:,4);

% 2b) parse orientation:
% orientation is encoded as quaternion:
q0 = pf(:,6);
q1 = pf(:,7);
q2 = pf(:,8);
q3 = pf(:,9);

% 2c) convert quaternion to Euler angles:
% (replace quat2eul_dl with quat2eul if you have Robotics System Toolbox)
[psi, theta, phi] = quat2eul_dl(q0,q1,q2,q3);

% 3a) parse x-, y-, and z-velocities:
vx = vf(:,2);
vy = vf(:,3);
vz = vf(:,4);

% 3b) parse angular velocities:
wx = vf(:,5);
wy = vf(:,6);
wz = vf(:,7);

% 4a) parse x-, y-, and z-forces:
Fx = ff(:,2);
Fy = ff(:,3);
Fz = ff(:,4);

% 4b) parse moments about x-, y-, and z-axes:
Mx = ff(:,5);
My = ff(:,6);
Mz = ff(:,7);

% 5) Correct for Chrono frame orientation (rotate 180 about z-axis)
px = -px;
py = -py;

vx = -vx;
vy = -vy;

Fx = -Fx;
Fy = -Fy;

% 6) Convert to units to MKS where necessary (i.e. pos & vel):
px = 0.01*px;
py = 0.01*py;
pz = 0.01*pz;

vx = 0.01*vx;
vy = 0.01*vy;
vz = 0.01*vz;

% fprintf('\tgamma = %f degrees.\n',(180/pi)*atan2(vz(1),vx(1)));

% wx = 0.001*wx;
% wy = 0.001*wy;
% wz = 0.001*wz;

Mx = Mx*(1e-6);
My = My*(1e-6);
Mz = Mz*(1e-6);

% 7) subtract off ~initial z-position so foot begins at boundary of
% granular domain:
pz(1)
pz = pz + params.geom.foot_radius*sin(theta(1)) - pz(1);

%% Plot Chrono stuff

% 1) plot config, vels, & forces vs time:
figure('units','normalized','outerposition',[0 0 1 1])

% 1a-i) plot vertical position vs time:
subplot(3,3,1)
plot(t,100*pz,'-','LineWidth',2);
ylabel('$z$ [cm]')
title('Vertical motion')

% 1a-ii) plot x- and y- position vs time (one of these should remain 0):
subplot(3,3,2)
plot(t,100*px,'-','LineWidth',2);hold on;
plot(t,100*py,'-','LineWidth',2);hold off;
legend('$x$','$y$','Location','Best');
ylabel('$x,y$ [cm]')
title({['Chrono Simulation: $v_0 = ',num2str(100*impact_speed_MKS,3),...
    '$ cm/s, $\theta_0 = ',num2str((180/pi)*impact_angle_rad,3),'^{\circ}$'],...
    'Horizontal motion'})

% 1a-iii) plot orientation (Euler angles) vs time:
subplot(3,3,3)
plot(t,psi,'-','LineWidth',2);hold on;
plot(t,theta,'-','LineWidth',2);
plot(t,phi,'-','LineWidth',2);hold off;
legend('$\psi$','$\theta$','$\phi$','Location','Best');
ylabel('angle [rad]')
title('Rotation')

% 1b-i) plot vertical velocity vs time:
subplot(3,3,4)
plot(t,100*vz,'-','LineWidth',2);
ylabel('$\dot{z}$ [cm/s]')

% 1b-ii) plot x- and y- velocity vs time (one of these should remain 0):
subplot(3,3,5)
plot(t,100*vx,'-','LineWidth',2);hold on;
plot(t,100*vy,'-','LineWidth',2);hold off;
legend('$\dot{x}$','$\dot{y}$','Location','Best');
ylabel('$\dot{x},\dot{y}$ [cm/s]')

% 1b-iii) plot angular velocities vs time:
subplot(3,3,6)
plot(t,wx,'-','LineWidth',2);hold on;
plot(t,wy,'-','LineWidth',2);
plot(t,wz,'-','LineWidth',2);hold off;
legend('$\dot{\psi}$','$\dot{\theta}$','$\dot{\phi}$','Location','Best');
ylabel('anglular velocity [rad/s]')

% 1c-i) plot vertical GRF vs time:
subplot(3,3,7)
plot(t,Fz,'-','LineWidth',2);
ylabel('$F_z$ [N]')

% 1c-ii) plot x- and y- GRF vs time (should one of these remain 0?):
subplot(3,3,8)
plot(t,Fx,'-','LineWidth',2);hold on;
plot(t,Fy,'-','LineWidth',2);hold off;
legend('$F_x$','$F_y$','Location','Best');
ylabel('$F_x,F_y$ [N]')
xlabel('$t$ [s]')

% Fx

% 1c-iii) plot ground reaction moments vs time:
subplot(3,3,9)
plot(t,Mx,'-','LineWidth',2);hold on;
plot(t,My,'-','LineWidth',2);
plot(t,Mz,'-','LineWidth',2);hold off;
legend('$M_x$','$M_y$','$M_z$','Location','Best');
ylabel('$M_x, M_y, M_z$ [N$\cdot$m]')

%fname=[path_tostrcat(s1,...,sN)_csvs, '/DEM_v=', num2str(impact_speed_MKS,3),'.fig'];
fname=strcat(path_to_csvs,'/DEM_v=',num2str(impact_speed_MKS,3),'.fig')
fprintf('%s\n',fname)

saveas(figure(1),fname);
fname=strcat(path_to_csvs,'/DEM_v=',num2str(impact_speed_MKS,3),'.png');
%saveas(figure(1),fname);
%saveas(figure(1),fname);

% return

%% Animate Chrono simulation of general planar foot motion
foot_state = [px(1:10:end),...
              vx(1:10:end),...
              pz(1:10:end),...
              vz(1:10:end),...
              theta(1:10:end),...
              wy(1:10:end)];

foot_state_original = [px(1:10:end),...
              vx(1:10:end),...
              pz(1:10:end),...
              vz(1:10:end),...
              theta(1:10:end),...
              wy(1:10:end)];

 foot_state_original = [px,...
              vx,...
              pz,...
              vz,...
              theta,...
              wy];      
          
ulist = zeros(size(foot_state,1),3);

% pause(1);
% hfig = figure('Renderer', 'painters', 'Position', [10 10 900 600]);
% trace_opt = 't'; % set to 't' to display a trace of CoM
% % movie_name = 'gpm_DEM_traj1.avi'; % set to '' to disable movie-recording
% movie_name = '';
% animate_foot(foot_state,ulist,params,trace_opt,movie_name,hfig);


params.init_state = [px(1);
                     vx(1);
                     pz(1);
                     vz(1);
                     theta(1);
                     wy(1)];
                 
params.init_state
          

tspan = t;
% Simulate:
ode_opts = odeset('Events',@(t,state) stopEvents(t,state,params));
[tsim,foot_state,te,ye,ie] = ode15s(@(t,foot_state) foot_dynamics(...
    t,foot_state,params.init_wrench,params), tspan, ...
    params.init_state,ode_opts);

% Post-process the simulation:
% pre-allocate a bunch of stuff
ulist = zeros(numel(tsim),numel(params.init_wrench));
grf_list = zeros(numel(tsim),5);


grf_neural_net = ones(numel(tsim), 3) * 10.0;


all_depths = zeros(numel(tsim),1);
all_vel_z = zeros(numel(tsim),1);
all_vel_x = zeros(numel(tsim),1);
all_gamma = zeros(numel(tsim),1);
all_beta = zeros(numel(tsim),1);
all_theta_dt = zeros(numel(tsim),1);

grf_grad_list = zeros(numel(tsim),3,6);
gran_top = pz(1);

for i = 1:numel(tsim)
    ulist(i,:) = params.init_wrench;
    
    % Re-compute GRF and gradient of GRF at each timestep:
    [grf_tmp, grf_grad_tmp] = get_grf(foot_state(i,:),ulist(i,:),params);
    grf_list(i,:) = [grf_tmp.F_x,...
                    grf_tmp.r_x,...
                    grf_tmp.F_y,...
                    grf_tmp.r_y,...
                    grf_tmp.M_z];
end

M = zeros(numel(tsim), 5);
%ground_model = groundReactionModel1();
ground_model = groundReactionModel2();
length = 80;
for i = 1:numel(tsim)
    zero_wrench = [0.0, 0.0, 0.0]; % params.init_wrench;
    
    beta = foot_state_original(i, 5);  
    
    vel_x = foot_state_original(i, 2);
    vel_z = foot_state_original(i, 4);
    theta_dt = -foot_state_original(i, 6);
    
    gamma = atan2(vel_z, vel_x) + 3.14/2.0;
    depth = -(foot_state_original(i, 3)); 
    
    all_depths(i, 1) = depth;
    all_vel_z(i, 1) = vel_z;
    all_vel_x(i, 1) = vel_x;
    all_gamma(i, 1) = gamma;
    all_beta(i, 1) = beta;
    all_theta_dt(i, 1) = theta_dt;
    
    M(i,1) = gamma;
    M(i,2) = beta;
    M(i,3) = depth;
    M(i,4) = vel_x;
    M(i, 5) = vel_z;
    
    %[grf_x, grf_z, torque] = ground_model.computeGRF(gamma, beta, depth, vel_x, -vel_z, theta_dt);
    [grf_x, grf_z, torque] = ground_model.computeGRF(gamma, beta, depth, vel_x, vel_z, theta_dt);
    
    grf_neural_net(i,1) = min(8.0, grf_x); %/ 100.0;
    grf_neural_net(i,2) = max(-15.0, grf_z); % / 100.0;
    grf_neural_net(i,3) = torque;

end

csvwrite('/home/peterjochem/Desktop/trajectory.csv', M);

%% Plot RFT stuff
% figure;
% % 1a-i) plot vertical position vs time:
% subplot(3,3,1)
% plot(tsim,100*foot_state(:,3),'-','LineWidth',2);
% ylabel('$z$ [cm]')
% title('Vertical motion')
% 
% % 1a-ii) plot x- and y- position vs time (one of these should remain 0):
% subplot(3,3,2)
% plot(tsim,100*foot_state(:,1),'-','LineWidth',2);
% ylabel('$x$ [cm]')
% title({'MATLAB Simulation','Horizontal motion'})
% 
% % 1a-iii) plot orientation (Euler angles) vs time:
% subplot(3,3,3)
% plot(tsim,foot_state(:,5),'-','LineWidth',2);
% ylabel('$\theta$ [rad]')
% title('Rotation')
% 
% % 1b-i) plot vertical velocity vs time:
% subplot(3,3,4)
% plot(tsim,100*foot_state(:,4),'-','LineWidth',2);
% ylabel('$\dot{z}$ [cm/s]')
% 
% % 1b-ii) plot x-velocity vs time:
% subplot(3,3,5)
% plot(tsim,100*foot_state(:,2),'-','LineWidth',2);
% ylabel('$\dot{x}$ [cm/s]')
% 
% % 1b-iii) plot angular velocities vs time:
% subplot(3,3,6)
% plot(tsim,foot_state(:,6),'-','LineWidth',2);
% ylabel('$\dot{\theta}$ [rad]')
% 
% % 1c-i) plot vertical GRF vs time:
% subplot(3,3,7)
% plot(tsim,grf_list(:,3),'-','LineWidth',2);
% ylabel('$F_z$ [N]')
% 
% % 1c-ii) plot horizontal GRF vs time (should one of these remain 0?):
% subplot(3,3,8)
% plot(tsim,grf_list(:,1),'-','LineWidth',2);
% ylabel('$F_x$ [N]')
% xlabel('$t$ [s]')
% 
% % 1c-iii) plot ground reaction moment vs time:
% subplot(3,3,9)
% plot(tsim,grf_list(:,5),'-','LineWidth',2);
% ylabel('$M_y$ [N$\cdot$m]')

%% Plot RFT and Chrono together for comparison:

figure('units','normalized','outerposition',[0 0 1 1])

%{
% 1a-i) plot vertical position vs time:
subplot(3,3,1)
plot(tsim,100*foot_state(:,3),'-','LineWidth',2); hold on;
plot(t(1:numel(tsim)),100*pz(1:numel(tsim)),':','LineWidth',2); hold off;
legend('RFT','DEM','Location','Best');
ylabel('$z$ [cm]')
title('Vertical motion')

% 1a-ii) plot x- and y- position vs time (one of these should remain 0):
subplot(3,3,2)
plot(tsim,100*foot_state(:,1),'-','LineWidth',2); hold on;
plot(t(1:numel(tsim)),100*px(1:numel(tsim)),':','LineWidth',2); hold off;
legend('RFT','DEM','Location','Best');
ylabel('$x$ [cm]')
title({['MATLAB (RFT) vs Chrono (DEM): $v_0 = ',...
    num2str(100*impact_speed_MKS,3),'$ cm/s, $\theta_0 = ',...
    num2str((180/pi)*impact_angle_rad,3),'^{\circ}$'],'Horizontal motion'})

% 1a-iii) plot orientation (Euler angles) vs time:
subplot(3,3,3)
plot(tsim,foot_state(:,5),'-','LineWidth',2); hold on;
plot(t(1:numel(tsim)),theta(1:numel(tsim)),':','LineWidth',2); hold off;
legend('RFT','DEM','Location','Best');
ylabel('$\theta$ [rad]')
title('Rotation')

% 1b-i) plot vertical velocity vs time:
subplot(3,3,4)
plot(tsim,100*foot_state(:,4),'-','LineWidth',2); hold on;
plot(t(1:numel(tsim)),100*vz(1:numel(tsim)),':','LineWidth',2); hold off;
legend('RFT','DEM','Location','Best');
ylabel('$\dot{z}$ [cm/s]')

% 1b-ii) plot x-velocity vs time:
subplot(3,3,5)
plot(tsim,100*foot_state(:,2),'-','LineWidth',2); hold on;
plot(t(1:numel(tsim)),100*vx(1:numel(tsim)),':','LineWidth',2); hold off;
legend('RFT','DEM','Location','Best');
ylabel('$\dot{x}$ [cm/s]')

% 1b-iii) plot angular velocities vs time:
subplot(3,3,6)
plot(tsim,foot_state(:,6),'-','LineWidth',2); hold on;
plot(t(1:numel(tsim)),wy(1:numel(tsim)),':','LineWidth',2); hold off;
legend('RFT','DEM','Location','Best');
ylabel('$\dot{\theta}$ [rad]')
%}

% 1c-i) plot vertical GRF vs time:
subplot(3,3,7)
plot(tsim,grf_list(:,3),'-','LineWidth',2);hold on;
plot(tsim, 1 * grf_neural_net(:,2),'-','LineWidth',2);hold on;
%plot(y1, 1 * grf_neural_net(:,2),'-','LineWidth',2);hold on;


plot(t(1:numel(tsim)),Fz(1:numel(tsim)),':','LineWidth',2); hold on;
legend('RFT', 'Learned Model','Chrono','Location','Best');
ylabel('$F_z$ [N]')

% 1c-ii) plot horizontal GRF vs time:
subplot(3,3,8)
plot(tsim, grf_list(:,1),'-','LineWidth',2);hold on;
plot(tsim, -1 * grf_neural_net(:,1),'-','LineWidth',2);hold on;
plot(t(1:numel(tsim)),Fx(1:numel(tsim)),':','LineWidth',2); hold off
legend('RFT','Learned Model', 'DEM','Location','Best');
ylabel('$F_x$ [N]')
xlabel('$t$ [s]')

% 1c-iii) plot ground reaction moment vs time:
subplot(3,3,9)
plot(tsim,grf_list(:,5),'-','LineWidth',2);hold on;
plot(tsim, 1 * grf_neural_net(:,3),'-','LineWidth',2);hold on;
plot(t(1:numel(tsim)),My(1:numel(tsim)),':','LineWidth',2); hold off
legend('RFT', 'Learned Model' ,'DEM','Location','Best');
ylabel('$M_y$ [N$\cdot$m]')

% Plot the Plate's State Variables
subplot(3,3,1)
plot(t(1:numel(tsim)), all_depths(1:numel(tsim)),':','LineWidth',2); hold off;
legend('DEM','Location','Best');
ylabel('depth (m)')

subplot(3,3,2)
plot(t(1:numel(tsim)), all_vel_x(1:numel(tsim)),':','LineWidth',2); hold off;
legend('DEM','Location','Best');
ylabel('velocity-x (m/s)')

subplot(3,3,3)
plot(t(1:numel(tsim)), all_vel_z(1:numel(tsim)),':','LineWidth',2); hold off;
legend('DEM','Location','Best');
ylabel('velocity-z (m/s)')

subplot(3,3,4)
plot(t(1:numel(tsim)), all_gamma(1:numel(tsim)),':','LineWidth',2); hold off;
legend('DEM','Location','Best');
ylabel('gamma (rads)')

subplot(3,3,5)
plot(t(1:numel(tsim)), all_beta(1:numel(tsim)),':','LineWidth',2); hold off;
legend('DEM','Location','Best');
ylabel('beta (rads)')

subplot(3,3,6)
plot(t(1:numel(tsim)), all_theta_dt(1:numel(tsim)),':','LineWidth',2); hold off;
legend('DEM','Location','Best');
ylabel('theta-dt (rads/s)')


fname=strcat(path_to_csvs,'/RFT_and_DEM_v=',num2str(impact_speed_MKS,3),'.fig');
saveas(figure(2),fname);
%saveas(figure(2),[path_to_csvs,'/RFT_and_DEM_v=',num2str(impact_speed_MKS,3),'.png']);

%% Animate RFT-based simulation of general planar foot motion
% pause(1);
% hfig2 = figure('Renderer', 'painters', 'Position', [10 10 900 600]);
% trace_opt = 't'; % set to 't' to display a trace of CoM
% % movie_name = 'gpm_RFT_traj1.avi'; % set to '' to disable movie-recording
% movie_name = '';
% animate_foot(foot_state,ulist,params,trace_opt,movie_name,hfig2);

%data = [px, vx, pz, vz, theta, wy, Fx, Fz, My];              
%writematrix(data,'data.csv') 

end