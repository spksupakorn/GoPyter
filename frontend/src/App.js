import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

const API_URL = process.env.REACT_APP_BACKEND_URL || 'http://localhost:8080/api/v1';

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [user, setUser] = useState(null);
  const [jupyterStatus, setJupyterStatus] = useState(null);
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [showRegister, setShowRegister] = useState(false);
  const [registerData, setRegisterData] = useState({
    username: '',
    email: '',
    password: '',
    fullName: ''
  });

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      fetchProfile(token);
    }
  }, []);

  useEffect(() => {
    // Auto-refresh Jupyter status every 5 seconds when logged in
    if (isLoggedIn) {
      const interval = setInterval(() => {
        checkJupyterStatus();
      }, 5000);
      return () => clearInterval(interval);
    }
  }, [isLoggedIn]);

  const fetchProfile = async (token) => {
    try {
      const response = await axios.get(`${API_URL}/profile`, {
        headers: { Authorization: `Bearer ${token}` }
      });
      setUser(response.data);
      setIsLoggedIn(true);
      checkJupyterStatus(token);
    } catch (error) {
      localStorage.removeItem('token');
    }
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    try {
      const response = await axios.post(`${API_URL}/login`, {
        username,
        password
      });
      localStorage.setItem('token', response.data.token);
      setUser(response.data.user);
      setIsLoggedIn(true);
      setUsername('');
      setPassword('');
    } catch (error) {
      setError(error.response?.data?.error || 'Login failed');
    }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setError('');
    try {
      await axios.post(`${API_URL}/register`, {
        username: registerData.username,
        email: registerData.email,
        password: registerData.password,
        full_name: registerData.fullName
      });
      // Auto login after successful registration
      const loginResponse = await axios.post(`${API_URL}/login`, {
        username: registerData.username,
        password: registerData.password
      });
      localStorage.setItem('token', loginResponse.data.token);
      setUser(loginResponse.data.user);
      setIsLoggedIn(true);
      setRegisterData({ username: '', email: '', password: '', fullName: '' });
      setShowRegister(false);
    } catch (error) {
      setError(error.response?.data?.error || 'Registration failed');
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('token');
    setIsLoggedIn(false);
    setUser(null);
    setJupyterStatus(null);
  };

  const checkJupyterStatus = async (token) => {
    try {
      const response = await axios.get(`${API_URL}/jupyter/status`, {
        headers: { Authorization: `Bearer ${token || localStorage.getItem('token')}` }
      });
      setJupyterStatus(response.data);
    } catch (error) {
      console.error('Failed to check Jupyter status', error);
    }
  };

  const startJupyter = async () => {
    try {
      const response = await axios.post(`${API_URL}/jupyter/start`, {}, {
        headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
      });
      const jupyterURL = response.data.jupyter_url;
      window.open(jupyterURL, '_blank');
      checkJupyterStatus();
    } catch (error) {
      setError(error.response?.data?.error || 'Failed to start Jupyter');
    }
  };

  const stopJupyter = async () => {
    try {
      await axios.post(`${API_URL}/jupyter/stop`, {}, {
        headers: { Authorization: `Bearer ${localStorage.getItem('token')}` }
      });
      checkJupyterStatus();
    } catch (error) {
      setError(error.response?.data?.error || 'Failed to stop Jupyter');
    }
  };

  if (!isLoggedIn) {
    return (
      <div className="App">
        <div className="login-container">
          <h1>GoPyter Portal</h1>
          
          {!showRegister ? (
            // Login Form
            <>
              <form onSubmit={handleLogin}>
                <input
                  type="text"
                  placeholder="Username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                />
                <input
                  type="password"
                  placeholder="Password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
                <button type="submit">Login</button>
              </form>
              {error && <div className="error">{error}</div>}
              <div className="register-link">
                <p>Don't have an account?</p>
                <button 
                  onClick={() => {
                    setShowRegister(true);
                    setError('');
                  }}
                  className="link-button"
                >
                  Create Account
                </button>
              </div>
            </>
          ) : (
            // Register Form
            <>
              <h2>Create Account</h2>
              <form onSubmit={handleRegister}>
                <input
                  type="text"
                  placeholder="Username"
                  value={registerData.username}
                  onChange={(e) => setRegisterData({...registerData, username: e.target.value})}
                  required
                />
                <input
                  type="email"
                  placeholder="Email"
                  value={registerData.email}
                  onChange={(e) => setRegisterData({...registerData, email: e.target.value})}
                  required
                />
                <input
                  type="text"
                  placeholder="Full Name (Optional)"
                  value={registerData.fullName}
                  onChange={(e) => setRegisterData({...registerData, fullName: e.target.value})}
                />
                <input
                  type="password"
                  placeholder="Password (min 6 characters)"
                  value={registerData.password}
                  onChange={(e) => setRegisterData({...registerData, password: e.target.value})}
                  required
                  minLength="6"
                />
                <button type="submit">Register</button>
              </form>
              {error && <div className="error">{error}</div>}
              <div className="register-link">
                <p>Already have an account?</p>
                <button 
                  onClick={() => {
                    setShowRegister(false);
                    setError('');
                  }}
                  className="link-button"
                >
                  Back to Login
                </button>
              </div>
            </>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="App">
      <header className="App-header">
        <h1>Welcome, {user?.full_name || user?.username}!</h1>
        <button onClick={handleLogout}>Logout</button>
      </header>
      
      <main className="main-content">
        <div className="jupyter-section">
          <h2>Your Jupyter Notebook</h2>
          
          {jupyterStatus?.status === 'active' ? (
            <div className="session-active">
              <p>✅ Your Jupyter session is active</p>
              <p>Started: {new Date(jupyterStatus.session.started_at).toLocaleString()}</p>
              <button onClick={() => startJupyter()}>Open Jupyter</button>
              <button onClick={stopJupyter} className="stop-btn">Stop Session</button>
            </div>
          ) : (
            <div className="session-inactive">
              <p>No active Jupyter session</p>
              <button onClick={startJupyter}>Start Jupyter</button>
            </div>
          )}
        </div>

        {error && <div className="error">{error}</div>}
      </main>
    </div>
  );
}

export default App;