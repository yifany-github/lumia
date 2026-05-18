import React, { useState } from 'react';
import { Users, Settings, Activity, Shield, Trash2, Edit2, Search, ArrowLeft, MoreVertical, CheckCircle2, XCircle } from 'lucide-react';

interface AdminPanelProps {
  onBack: () => void;
}

const mockUsers = [
  { id: '1', name: 'Guest Traveler', email: 'guest@lumia.ai', role: 'user', status: 'active', joined: '2024-10-20', entries: 12 },
  { id: '2', name: 'Admin User', email: 'admin@lumia.ai', role: 'admin', status: 'active', joined: '2024-01-15', entries: 45 },
  { id: '3', name: 'Sarah Jenkins', email: 'sarah.j@example.com', role: 'user', status: 'inactive', joined: '2024-11-05', entries: 3 },
  { id: '4', name: 'Michael Chen', email: 'm.chen@example.com', role: 'user', status: 'active', joined: '2024-12-01', entries: 28 },
  { id: '5', name: 'Emma Watson', email: 'emma.w@example.com', role: 'user', status: 'active', joined: '2024-12-10', entries: 7 },
];

const AdminPanel: React.FC<AdminPanelProps> = ({ onBack }) => {
  const [users, setUsers] = useState(mockUsers);
  const [searchTerm, setSearchTerm] = useState('');

  const filteredUsers = users.filter(user => 
    user.name.toLowerCase().includes(searchTerm.toLowerCase()) || 
    user.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const handleDeleteUser = (id: string) => {
    if (window.confirm('Are you sure you want to delete this user?')) {
      setUsers(users.filter(u => u.id !== id));
    }
  };

  const toggleUserStatus = (id: string) => {
    setUsers(users.map(u => {
      if (u.id === id) {
        return { ...u, status: u.status === 'active' ? 'inactive' : 'active' };
      }
      return u;
    }));
  };

  return (
    <div className="min-h-screen bg-background text-foreground font-sans">
      <header className="sticky top-0 z-30 bg-background/80 backdrop-blur-md border-b border-border/50 px-4 md:px-6 py-4 flex items-center justify-between">
         <div className="flex items-center gap-3">
             <div className="w-10 h-10 bg-primary/10 rounded-xl flex items-center justify-center text-primary shadow-sm">
                 <Shield size={20} />
             </div>
             <h1 className="font-serif font-bold text-xl tracking-tight">Lumia <span className="text-muted-foreground font-sans font-normal text-base ml-1 hidden sm:inline">Admin</span></h1>
         </div>
         <button onClick={onBack} className="flex items-center gap-2 text-sm font-bold text-muted-foreground hover:text-primary transition-colors">
            <ArrowLeft size={16} /> Back to App
         </button>
      </header>

      <main className="max-w-7xl mx-auto px-4 py-8">
        <div className="mb-8">
            <h2 className="font-serif text-3xl font-bold mb-2">User Management</h2>
            <p className="text-muted-foreground text-sm">Manage user accounts, roles, and system access.</p>
        </div>

        {/* Stats Overview */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
            <div className="bg-card p-6 rounded-2xl border border-border shadow-sm">
                <div className="flex items-center justify-between mb-4">
                    <div className="p-2 bg-primary/10 text-primary rounded-lg"><Users size={20} /></div>
                    <span className="text-xs font-bold text-green-500 bg-green-500/10 px-2 py-1 rounded-full">+12%</span>
                </div>
                <h3 className="text-2xl font-bold">{users.length}</h3>
                <p className="text-xs text-muted-foreground uppercase tracking-wider font-bold mt-1">Total Users</p>
            </div>
            <div className="bg-card p-6 rounded-2xl border border-border shadow-sm">
                <div className="flex items-center justify-between mb-4">
                    <div className="p-2 bg-secondary/10 text-secondary rounded-lg"><Activity size={20} /></div>
                    <span className="text-xs font-bold text-green-500 bg-green-500/10 px-2 py-1 rounded-full">+5%</span>
                </div>
                <h3 className="text-2xl font-bold">{users.filter(u => u.status === 'active').length}</h3>
                <p className="text-xs text-muted-foreground uppercase tracking-wider font-bold mt-1">Active Users</p>
            </div>
            <div className="bg-card p-6 rounded-2xl border border-border shadow-sm">
                <div className="flex items-center justify-between mb-4">
                    <div className="p-2 bg-blue-500/10 text-blue-500 rounded-lg"><Settings size={20} /></div>
                </div>
                <h3 className="text-2xl font-bold">{users.reduce((acc, curr) => acc + curr.entries, 0)}</h3>
                <p className="text-xs text-muted-foreground uppercase tracking-wider font-bold mt-1">Total Entries</p>
            </div>
            <div className="bg-card p-6 rounded-2xl border border-border shadow-sm">
                <div className="flex items-center justify-between mb-4">
                    <div className="p-2 bg-red-500/10 text-red-500 rounded-lg"><Shield size={20} /></div>
                </div>
                <h3 className="text-2xl font-bold">{users.filter(u => u.role === 'admin').length}</h3>
                <p className="text-xs text-muted-foreground uppercase tracking-wider font-bold mt-1">Admins</p>
            </div>
        </div>

        {/* Users Table */}
        <div className="bg-card rounded-2xl border border-border shadow-sm overflow-hidden">
            <div className="p-4 border-b border-border flex flex-col sm:flex-row justify-between items-center gap-4">
                <div className="relative w-full sm:w-96">
                    <Search className="absolute left-3 top-1/2 -translate-y-1/2 text-muted-foreground" size={18} />
                    <input 
                        type="text" 
                        placeholder="Search users by name or email..." 
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        className="w-full pl-10 pr-4 py-2 bg-muted/50 border border-border rounded-xl focus:outline-none focus:ring-2 focus:ring-primary/20 transition-all text-sm"
                    />
                </div>
                <button className="w-full sm:w-auto px-4 py-2 bg-primary text-primary-foreground rounded-xl text-sm font-bold hover:bg-primary/90 transition-colors">
                    Add User
                </button>
            </div>
            
            <div className="overflow-x-auto">
                <table className="w-full text-left border-collapse">
                    <thead>
                        <tr className="bg-muted/30 text-xs uppercase tracking-wider text-muted-foreground border-b border-border">
                            <th className="p-4 font-bold">User</th>
                            <th className="p-4 font-bold">Role</th>
                            <th className="p-4 font-bold">Status</th>
                            <th className="p-4 font-bold">Joined</th>
                            <th className="p-4 font-bold">Entries</th>
                            <th className="p-4 font-bold text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {filteredUsers.map((user) => (
                            <tr key={user.id} className="border-b border-border/50 hover:bg-muted/10 transition-colors">
                                <td className="p-4">
                                    <div className="flex items-center gap-3">
                                        <div className="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center text-primary font-bold text-xs">
                                            {user.name.charAt(0)}
                                        </div>
                                        <div>
                                            <div className="font-bold text-sm text-foreground">{user.name}</div>
                                            <div className="text-xs text-muted-foreground">{user.email}</div>
                                        </div>
                                    </div>
                                </td>
                                <td className="p-4">
                                    <span className={`inline-flex items-center px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-widest ${user.role === 'admin' ? 'bg-purple-500/10 text-purple-500' : 'bg-muted text-muted-foreground'}`}>
                                        {user.role}
                                    </span>
                                </td>
                                <td className="p-4">
                                    <button 
                                        onClick={() => toggleUserStatus(user.id)}
                                        className={`inline-flex items-center gap-1 px-2 py-1 rounded-md text-[10px] font-bold uppercase tracking-widest transition-colors ${user.status === 'active' ? 'bg-green-500/10 text-green-500 hover:bg-green-500/20' : 'bg-red-500/10 text-red-500 hover:bg-red-500/20'}`}
                                    >
                                        {user.status === 'active' ? <CheckCircle2 size={12} /> : <XCircle size={12} />}
                                        {user.status}
                                    </button>
                                </td>
                                <td className="p-4 text-sm text-muted-foreground">{user.joined}</td>
                                <td className="p-4 text-sm text-muted-foreground">{user.entries}</td>
                                <td className="p-4 text-right">
                                    <div className="flex items-center justify-end gap-2">
                                        <button className="p-1.5 text-muted-foreground hover:text-primary transition-colors rounded-md hover:bg-primary/10">
                                            <Edit2 size={16} />
                                        </button>
                                        <button 
                                            onClick={() => handleDeleteUser(user.id)}
                                            className="p-1.5 text-muted-foreground hover:text-red-500 transition-colors rounded-md hover:bg-red-500/10"
                                        >
                                            <Trash2 size={16} />
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        ))}
                        {filteredUsers.length === 0 && (
                            <tr>
                                <td colSpan={6} className="p-8 text-center text-muted-foreground">
                                    No users found matching your search.
                                </td>
                            </tr>
                        )}
                    </tbody>
                </table>
            </div>
        </div>
      </main>
    </div>
  );
};

export default AdminPanel;
